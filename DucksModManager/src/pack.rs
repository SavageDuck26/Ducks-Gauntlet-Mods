//! The manager's own copy of the pack.
//!
//! There is no git here on purpose. Whether the pack has moved on is one small request to GitHub's
//! API for the branch's latest commit SHA; the archive itself is a plain HTTPS download of that
//! branch, unpacked with `tar`/`flate2` only when the SHA says something changed. That means one
//! small HTTP crate instead of a git implementation, no git, ssh or gh on the player's machine, and
//! the Mozilla roots compiled into the binary by ureq's own rustls setup, so nothing depends on the
//! system certificate store.
//!
//! What a snapshot costs us is history: a mod is still identified by a fingerprint of its files,
//! because there is no checkout to diff against. That is all `install.rs` ever needed.
//!
//! Everything in here is about getting the pack onto disk and reading it. Deciding what to do with
//! the files is `install.rs`'s job.

use std::collections::BTreeMap;
use std::fs;
use std::path::{Component, Path, PathBuf};
use std::time::Duration;

use sha2::{Digest, Sha256};

/// Folder inside the manager's appdata holding the pack copy.
pub const PACK_DIR: &str = "pack";

/// Where the commit SHA of the pack copy on disk is kept, so the next check can tell whether the
/// pack has moved on.
pub const VERSION_FILE: &str = "pack.version";

/// ureq starts with every timeout switched off. The SHA check runs before the window is first
/// drawn, so it gets a short deadline; the archive gets long enough for a slow line to finish.
const CHECK_TIMEOUT: Duration = Duration::from_secs(15);
const DOWNLOAD_TIMEOUT: Duration = Duration::from_secs(120);

/// A mod found in the pack. `<category>/<name>` is its path both in the pack and in the install.
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct PackMod {
    pub category: String,
    pub name: String,
}

impl PackMod {
    /// Where this mod sits, relative to the pack root and to the install root.
    ///
    /// For most mods that is `<category>/<name>`. But when the mod *is* the top-level folder — the
    /// pack ships `AddUtility(REQUIRED_FOR_MODS)` and `Trials Mods` that way, because the folder
    /// itself holds a `.lua` — the path is just that folder. Repeating it would point at a folder
    /// that does not exist, which is what made those two look like they were not installed.
    pub fn rel_path(&self) -> String {
        if self.category == self.name {
            self.category.clone()
        } else {
            format!("{}/{}", self.category, self.name)
        }
    }
}

/// One mod folder's files, keyed by path relative to the mod folder. Mods are small enough to hold
/// in memory, and this keeps the compare and merge code free of filesystem and git details.
pub type Tree = BTreeMap<String, Vec<u8>>;

/// The tarball for a branch: GitHub's archive of it, which is what the manager downloads. Public,
/// no token, and it redirects to codeload — which ureq follows.
pub fn archive_url(repo_url: &str, branch: &str) -> String {
    let base = repo_url.trim_end_matches('/');
    let base = base.strip_suffix(".git").unwrap_or(base);
    format!("{base}/archive/refs/heads/{branch}.tar.gz")
}

/// An HTTP agent with one deadline covering the whole request: resolve, connect, redirects and the
/// body. `ureq` ships with no timeout at all, which is not something the UI thread can afford.
fn agent(timeout: Duration) -> ureq::Agent {
    let config = ureq::Agent::config_builder()
        .timeout_global(Some(timeout))
        .build();

    ureq::Agent::new_with_config(config)
}

/// Downloads `url` to `dest`, streamed, so even a large archive never sits in memory.
pub fn download(url: &str, dest: &Path) -> Result<(), String> {
    let mut response = agent(DOWNLOAD_TIMEOUT)
        .get(url)
        .call()
        .map_err(|err| err.to_string())?;
    let mut body = response.body_mut().as_reader();

    if let Some(parent) = dest.parent() {
        fs::create_dir_all(parent).map_err(|err| err.to_string())?;
    }
    let mut file = fs::File::create(dest).map_err(|err| err.to_string())?;
    std::io::copy(&mut body, &mut file).map_err(|err| err.to_string())?;

    Ok(())
}

/// Unpacks a `.tar.gz` into `out`, which must be a fresh, empty folder.
///
/// Entries are walked by hand rather than handed to `Archive::unpack`, because that would happily
/// create symlinks and hard links. Only plain files and folders are written, and anything that
/// tries to leave `out` — a `..` part, or an absolute path — is refused outright.
pub fn unpack(archive: &Path, out: &Path) -> Result<(), String> {
    let file = fs::File::open(archive).map_err(|err| err.to_string())?;
    let mut tar = tar::Archive::new(flate2::read::GzDecoder::new(file));
    let entries = tar.entries().map_err(|err| err.to_string())?;

    for entry in entries {
        let mut entry = entry.map_err(|err| err.to_string())?;
        let path = entry.path().map_err(|err| err.to_string())?.into_owned();

        if !path
            .components()
            .all(|part| matches!(part, Component::Normal(_)))
        {
            return Err(format!("refusing to unpack {}", path.display()));
        }
        let target = out.join(&path);

        match entry.header().entry_type() {
            tar::EntryType::Directory => {
                fs::create_dir_all(&target).map_err(|err| err.to_string())?;
            }
            tar::EntryType::Regular => {
                if let Some(parent) = target.parent() {
                    fs::create_dir_all(parent).map_err(|err| err.to_string())?;
                }
                let mut file = fs::File::create(&target).map_err(|err| err.to_string())?;
                std::io::copy(&mut entry, &mut file).map_err(|err| err.to_string())?;
            }
            // Metadata entries carry no file of their own — GitHub's tarballs open with a
            // `pax_global_header` — so they are stepped over rather than refused.
            tar::EntryType::XHeader
            | tar::EntryType::XGlobalHeader
            | tar::EntryType::GNULongName => {}
            // Symlinks, hard links, devices: none of them belong in a mods folder.
            other => return Err(format!("refusing to unpack {} ({other:?})", path.display())),
        }
    }

    Ok(())
}

/// The pack is often wrapped in a folder or two — `Ducks-Modpack/` in the repo, plus GitHub's own
/// archive folder — so the wrapper is worked out from the mods rather than assumed: whatever every
/// mod path has in common is the wrapper, and a category is a folder below it. That keeps a mod's
/// category, and its install path, the same however the repo rearranges itself.
pub fn mods(root: &Path) -> Vec<PackMod> {
    let mut paths = Vec::new();
    collect_mods(root, "", &mut paths);

    let wrapper = wrapper_of(&paths);

    let mut found: Vec<PackMod> = paths
        .iter()
        .map(|path| {
            let short = path
                .strip_prefix(&wrapper)
                .unwrap_or(path)
                .trim_start_matches('/');

            match short.rsplit_once('/') {
                Some((category, name)) => PackMod {
                    category: category.to_owned(),
                    name: name.to_owned(),
                },
                // A mod sitting right at the top of the pack is its own category.
                None => PackMod {
                    category: short.to_owned(),
                    name: short.to_owned(),
                },
            }
        })
        .collect();

    found.sort_by_key(PackMod::rel_path);
    found
}

/// The folder inside the pack copy that holds a mod's files.
///
/// `rel` is the wrapper-free path the list and the install both use, but the pack copy can nest
/// everything one folder down — the repo keeps the pack in `Ducks-Modpack/` — so the wrapper has to
/// be put back before anything can be read. Trying the direct path first keeps a pack that is not
/// wrapped working, and a path that matches nothing comes back as-is so the caller reads an empty
/// tree and can say so, rather than silently finding nothing.
pub fn locate(pack_root: &Path, rel: &str) -> PathBuf {
    let direct = pack_root.join(rel);
    if direct.is_dir() {
        return direct;
    }

    for child in folders(pack_root) {
        let nested = child.join(rel);
        if nested.is_dir() {
            return nested;
        }
    }

    direct
}

/// The folder the pack keeps its written documentation in, below the same wrapper as the mods.
pub const DOCS_DIR: &str = "Docs";

/// The one file the manager shows: the pack's own read-me-first documentation.
pub const DOC_FILE: &str = "Modpack Documentation (READ THIS).md";

/// The pack's documentation file as it would be on disk. It is only there once the pack copy has
/// been fetched, so callers check rather than assume.
pub fn doc_path(pack_root: &Path) -> PathBuf {
    locate(pack_root, DOCS_DIR).join(DOC_FILE)
}

/// The pack's documentation, read as text for the panel beside the mod list.
///
/// The docs sit inside the same wrapper the mods do — the repo keeps the pack in `Ducks-Modpack/` —
/// so they are located exactly the way a mod is. A pack copy that has not been fetched yet simply
/// reads as nothing, which is not an error: the panel says so.
pub fn read_doc(pack_root: &Path) -> Option<String> {
    fs::read_to_string(doc_path(pack_root)).ok()
}

/// Whatever folder every mod sits inside, worked out from the mods themselves.
fn wrapper_of(paths: &[String]) -> String {
    let mut shared: Option<Vec<&str>> = None;

    for path in paths {
        let parent = path.rsplit_once('/').map(|(parent, _)| parent).unwrap_or("");
        let parts: Vec<&str> = if parent.is_empty() {
            Vec::new()
        } else {
            parent.split('/').collect()
        };

        shared = Some(match shared {
            None => parts,
            Some(kept) => kept
                .into_iter()
                .zip(parts)
                .take_while(|(one, other)| one == other)
                .map(|(one, _)| one)
                .collect(),
        });
    }

    let wrapper = shared.unwrap_or_default().join("/");

    // If nothing would be left below it, that "wrapper" was really a category — a pack holding a
    // single mod, say — so leave it alone.
    let leaves_categories = paths.iter().any(|path| {
        path.strip_prefix(&wrapper)
            .unwrap_or(path)
            .trim_start_matches('/')
            .contains('/')
    });

    if leaves_categories { wrapper } else { String::new() }
}

/// Reads a folder from disk into a [`Tree`], keyed by path relative to `dir`.
pub fn read_tree(dir: &Path) -> Tree {
    let mut tree = Tree::new();
    read_disk_into(dir, "", &mut tree);
    tree
}

/// Reads one mod folder out of the pack's history: how it looked at `commit`.
/// Walks down until it reaches a folder holding a `.lua` directly; that folder is the mod. Its path
/// is recorded relative to where the walk began.
fn collect_mods(dir: &Path, prefix: &str, found: &mut Vec<String>) {
    if holds_lua(dir) {
        if !prefix.is_empty() {
            found.push(prefix.to_owned());
        }
        return;
    }

    for child in folders(dir) {
        collect_mods(&child, &join(prefix, &file_name(&child)), found);
    }
}

/// Folders inside `dir`, ignoring dot-folders such as `.git`.
fn folders(dir: &Path) -> Vec<PathBuf> {
    let Ok(entries) = fs::read_dir(dir) else {
        return Vec::new();
    };

    let mut folders: Vec<PathBuf> = entries
        .flatten()
        .filter(|entry| entry.file_type().is_ok_and(|kind| kind.is_dir()))
        .map(|entry| entry.path())
        .filter(|path| !file_name(path).starts_with('.'))
        .collect();

    folders.sort();
    folders
}

/// True when `dir` holds a `.lua` file directly.
fn holds_lua(dir: &Path) -> bool {
    let Ok(entries) = fs::read_dir(dir) else {
        return false;
    };

    entries.flatten().any(|entry| {
        entry.file_type().is_ok_and(|kind| kind.is_file())
            && entry
                .file_name()
                .to_string_lossy()
                .to_ascii_lowercase()
                .ends_with(".lua")
    })
}

fn read_disk_into(dir: &Path, prefix: &str, tree: &mut Tree) {
    let Ok(entries) = fs::read_dir(dir) else {
        return;
    };

    for entry in entries.flatten() {
        let name = entry.file_name().to_string_lossy().into_owned();
        let path = join(prefix, &name);
        let Ok(kind) = entry.file_type() else {
            continue;
        };

        if kind.is_dir() {
            read_disk_into(&entry.path(), &path, tree);
        } else if kind.is_file()
            && let Ok(bytes) = fs::read(entry.path())
        {
            tree.insert(path, bytes);
        }
    }
}


/// What a refresh found.
pub enum Refreshed {
    /// The pack on disk is already this version.
    Unchanged { version: String },
    /// The pack moved on, and the copy was replaced.
    Changed { version: String },
}

/// Fetches the pack if the branch has moved on, and reports the commit either way.
///
/// The check is one small request for the branch's latest commit SHA, so an unchanged pack costs no
/// download at all. A moved one is unpacked into a fresh folder and only then swapped in, so a
/// failed download or a half-written unpack can never leave the pack copy in pieces.
pub fn refresh(pack_dir: &Path, repo_url: &str, branch: &str) -> Result<Refreshed, String> {
    let version = latest_sha(repo_url, branch)?;
    refresh_to(pack_dir, &version, &archive_url(repo_url, branch))
}

/// The pull half, with the commit and the archive URL already known: `refresh` gets both from
/// GitHub, while the tests point them at a local server and a temp folder.
fn refresh_to(pack_dir: &Path, version: &str, url: &str) -> Result<Refreshed, String> {
    if version_of(pack_dir).as_deref() == Some(version) && pack_dir.is_dir() {
        return Ok(Refreshed::Unchanged {
            version: version.to_owned(),
        });
    }

    let archive = pack_dir.with_extension("download");
    download(url, &archive)?;

    let staging = pack_dir.with_extension("staging");
    fs::remove_dir_all(&staging).ok();
    fs::create_dir_all(&staging).map_err(|err| err.to_string())?;
    unpack(&archive, &staging)?;
    fs::remove_file(&archive).ok();

    // GitHub wraps the whole pack in a single `<repo>-<branch>` folder.
    let root = single_folder(&staging).unwrap_or_else(|| staging.clone());

    fs::remove_dir_all(pack_dir).ok();
    fs::rename(&root, pack_dir).map_err(|err| err.to_string())?;
    fs::remove_dir_all(&staging).ok();

    write_version(pack_dir, version)?;
    Ok(Refreshed::Changed {
        version: version.to_owned(),
    })
}

/// The SHA of the newest commit on `branch`, straight from GitHub's API.
///
/// This answers "is there anything to pull?" without downloading the pack: one small request, no
/// token. The archive has no published hash, so the commit it was built from is what identifies a
/// version of the pack.
pub fn latest_sha(repo_url: &str, branch: &str) -> Result<String, String> {
    let repo = github_repo(repo_url).ok_or_else(|| {
        format!("{repo_url} is not a github.com repository, so its latest commit cannot be checked")
    })?;
    let url = format!("https://api.github.com/repos/{repo}/git/refs/heads/{branch}");

    let mut response = agent(CHECK_TIMEOUT)
        .get(&url)
        .header("Accept", "application/vnd.github+json")
        .call()
        .map_err(|err| format!("could not ask GitHub for the latest commit: {err}"))?;
    let text = response
        .body_mut()
        .read_to_string()
        .map_err(|err| format!("could not read GitHub's answer: {err}"))?;

    sha_from_json(&text).ok_or_else(|| format!("GitHub's answer had no commit sha: {text}"))
}

/// The `owner/repo` part of a GitHub URL, which is what the API needs. A repository anywhere else
/// has no API to ask, so it comes back as `None` rather than being guessed at.
fn github_repo(repo_url: &str) -> Option<String> {
    let trimmed = repo_url.trim().trim_end_matches('/');
    let trimmed = trimmed.strip_suffix(".git").unwrap_or(trimmed);
    let rest = trimmed.strip_prefix("https://github.com/")?;

    let parts: Vec<&str> = rest.split('/').filter(|part| !part.is_empty()).collect();
    match parts.as_slice() {
        [owner, repo] => Some(format!("{owner}/{repo}")),
        _ => None,
    }
}

/// The `sha` out of the small refs object GitHub returns. A hand parser is enough because the shape
/// is fixed, and the value is only accepted when it is a full 40-character commit id.
fn sha_from_json(json: &str) -> Option<String> {
    let rest = &json[json.find("\"sha\"")? + "\"sha\"".len()..];
    let rest = rest[rest.find(':')? + 1..].trim_start();
    let rest = rest.strip_prefix('"')?;
    let sha = &rest[..rest.find('"')?];

    (sha.len() == 40 && sha.bytes().all(|byte| byte.is_ascii_hexdigit()))
        .then(|| sha.to_ascii_lowercase())
}

/// The commit SHA of the pack copy on disk, if it has one.
pub fn version_of(pack_dir: &Path) -> Option<String> {
    let text = fs::read_to_string(pack_dir.join(VERSION_FILE)).ok()?;
    let trimmed = text.trim();

    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_owned())
    }
}

/// A fingerprint of a mod's files: the same content always gives the same string, whatever order
/// the files came off disk in. This is what stands in for a commit id.
pub fn fingerprint(tree: &Tree) -> String {
    let mut hasher = Sha256::new();

    for (path, content) in tree {
        hasher.update(path.as_bytes());
        hasher.update([0]);
        hasher.update(content);
        hasher.update([0]);
    }

    short_hex(&hasher.finalize())
}

fn write_version(pack_dir: &Path, version: &str) -> Result<(), String> {
    fs::write(pack_dir.join(VERSION_FILE), format!("{version}\n")).map_err(|err| err.to_string())
}

/// The only folder inside `dir`, when there is exactly one and nothing else.
fn single_folder(dir: &Path) -> Option<PathBuf> {
    let entries: Vec<PathBuf> = fs::read_dir(dir)
        .ok()?
        .flatten()
        .map(|entry| entry.path())
        .collect();

    match entries.as_slice() {
        [only] if only.is_dir() => Some(only.clone()),
        _ => None,
    }
}

/// The first few bytes of a hash: plenty to tell one pack version from another by eye.
fn short_hex(bytes: &[u8]) -> String {
    bytes
        .iter()
        .take(8)
        .map(|byte| format!("{byte:02x}"))
        .collect()
}

fn join(prefix: &str, name: &str) -> String {
    if prefix.is_empty() {
        name.to_owned()
    } else {
        format!("{prefix}/{name}")
    }
}

fn file_name(path: &Path) -> String {
    path.file_name()
        .map(|name| name.to_string_lossy().into_owned())
        .unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    fn temp_root(name: &str) -> PathBuf {
        let root = std::env::temp_dir().join(name);
        fs::remove_dir_all(&root).ok();
        fs::create_dir_all(&root).expect("create the temp folder");
        root
    }

    fn write_file(path: &Path, text: &str) {
        fs::create_dir_all(path.parent().unwrap()).expect("create the parent folder");
        fs::write(path, text).expect("write the file");
    }

    fn text(tree: &Tree, path: &str) -> String {
        String::from_utf8_lossy(tree.get(path).expect("path in tree")).into_owned()
    }

    /// The rule the list is built on: a folder holding a `.lua` file is a mod, and everything under
    /// it belongs to that mod.
    #[test]
    fn mods_follow_the_folder_rule() {
        let root = temp_root("ducksmm_pack_scan");

        // Mirrors the real pack: two categories that hold a `.lua` themselves, and one that only
        // holds folders. The docs folder has no Lua at all, so it is not a mod either.
        let required = root.join("AddUtility(REQUIRED_FOR_MODS)");
        write_file(&required.join("script_main.lua"), "-- main");
        write_file(&required.join("Fixes").join("script_fix.lua"), "-- fix");
        write_file(&root.join("Trials Mods").join("script_main_trials.lua"), "-- trials");
        write_file(
            &root.join("Trials Mods").join("Peacemonger").join("script.lua"),
            "-- peace",
        );
        write_file(
            &root.join("Clientside Mods").join("Knossos").join("script.lua"),
            "-- knossos",
        );
        write_file(
            &root
                .join("Clientside Mods")
                .join("Knossos")
                .join("Extra_Quilts")
                .join("caves.lua"),
            "-- caves",
        );
        write_file(&root.join("Docs").join("Local Mods.md"), "docs");

        let found: Vec<String> = mods(&root).iter().map(PackMod::rel_path).collect();

        assert_eq!(
            found,
            vec![
                // The folder that holds a `.lua` itself is the mod, so its path is just the folder.
                "AddUtility(REQUIRED_FOR_MODS)".to_owned(),
                "Clientside Mods/Knossos".to_owned(),
                "Trials Mods".to_owned(),
            ]
        );

        fs::remove_dir_all(&root).ok();
    }

    /// Once the repo nests the pack inside `Ducks-Modpack/`, the categories are the folders *below*
    /// that — not the wrapper — so every install stays exactly where it already was.
    #[test]
    fn a_wrapped_pack_is_unwrapped() {
        let root = temp_root("ducksmm_pack_wrapped");
        let pack = root.join("Ducks-Modpack");

        write_file(
            &pack.join("AddUtility(REQUIRED_FOR_MODS)").join("script_main.lua"),
            "-- one",
        );
        write_file(
            &pack.join("Local Mods").join("FragileHeroes").join("script.lua"),
            "-- fragile",
        );
        write_file(
            &pack.join("Trials Mods").join("script_main_trials.lua"),
            "-- trials",
        );
        write_file(&root.join("README.md"), "docs");
        write_file(
            &pack.join(DOCS_DIR).join(DOC_FILE),
            "**Local Mods:**\n- *FragileHeroes:* every hit is fatal",
        );

        let found: Vec<String> = mods(&root).iter().map(PackMod::rel_path).collect();

        assert_eq!(
            found,
            vec![
                "AddUtility(REQUIRED_FOR_MODS)".to_owned(),
                "Local Mods/FragileHeroes".to_owned(),
                "Trials Mods".to_owned(),
            ]
        );

        // Reading a mod has to put the wrapper back: the list path is wrapper-free, the folder is
        // not, and joining the two was why nothing installed or updated after the pack moved.
        assert_eq!(
            locate(&root, "Local Mods/FragileHeroes"),
            pack.join("Local Mods").join("FragileHeroes")
        );

        // The docs are inside that same wrapper, so the panel on the right has to reach them the
        // same way a mod is reached.
        assert_eq!(doc_path(&root), pack.join(DOCS_DIR).join(DOC_FILE));
        assert!(
            read_doc(&root).is_some_and(|text| text.contains("every hit is fatal")),
            "the documentation should be found below the wrapper"
        );

        fs::remove_dir_all(&root).ok();
    }

    /// A pack copy that has not been fetched yet — or one shipping no docs — is not an error: there
    /// is simply nothing to show, and the panel says so.
    #[test]
    fn a_missing_documentation_file_reads_as_nothing() {
        let root = temp_root("ducksmm_pack_no_docs");
        write_file(
            &root.join("Local Mods").join("DucksUI").join("script.lua"),
            "-- ui",
        );

        assert!(read_doc(&root).is_none());

        fs::remove_dir_all(&root).ok();
    }

    #[test]
    fn read_tree_walks_nested_folders() {
        let root = temp_root("ducksmm_pack_tree");
        write_file(&root.join("script.lua"), "-- top");
        write_file(&root.join("Extra_Quilts").join("caves.lua"), "-- nested");

        let tree = read_tree(&root);

        assert_eq!(tree.len(), 2);
        assert_eq!(text(&tree, "script.lua"), "-- top");
        assert_eq!(text(&tree, "Extra_Quilts/caves.lua"), "-- nested");

        fs::remove_dir_all(&root).ok();
    }

    /// Builds a `.tar.gz`, so unpacking can be tested without a network. `escape` adds an entry
    /// whose path tries to leave the folder, which the tar crate's own writer refuses to produce —
    /// so it is written by hand, because reading one back has to be refused too.
    fn tarball(
        path: &Path,
        files: &[(&str, &str)],
        escape: Option<&str>,
        link: Option<&str>,
    ) {
        let file = fs::File::create(path).expect("create the archive");
        let encoder = flate2::write::GzEncoder::new(file, flate2::Compression::fast());
        let mut tar = tar::Builder::new(encoder);

        for (name, content) in files {
            let mut header = tar::Header::new_gnu();
            header.set_size(content.len() as u64);
            header.set_mode(0o644);
            header.set_cksum();
            tar.append_data(&mut header, name, content.as_bytes())
                .expect("append a file");
        }

        if let Some(name) = escape {
            let mut header = tar::Header::new_gnu();
            header.set_size(4);
            header.set_mode(0o644);
            if let Some(gnu) = header.as_gnu_mut() {
                let bytes = name.as_bytes();
                gnu.name[..bytes.len()].copy_from_slice(bytes);
            }
            header.set_cksum();
            tar.append(&header, &b"-- no"[..])
                .expect("append the hostile entry");
        }

        if let Some(name) = link {
            let mut header = tar::Header::new_gnu();
            header.set_entry_type(tar::EntryType::Symlink);
            header.set_size(0);
            header.set_mode(0o777);
            header.set_cksum();
            tar.append_link(&mut header, name, "/etc/passwd")
                .expect("append a link");
        }

        tar.into_inner()
            .expect("finish the tar")
            .finish()
            .expect("finish the gzip");
    }

    fn empty_dir(root: &Path) -> PathBuf {
        let out = root.join("out");
        fs::create_dir_all(&out).expect("create the output folder");
        out
    }

    #[test]
    fn archive_url_points_at_the_branch_archive() {
        assert_eq!(
            archive_url("https://github.com/SavageDuck26/Ducks-Gauntlet-Mods.git", "main"),
            "https://github.com/SavageDuck26/Ducks-Gauntlet-Mods/archive/refs/heads/main.tar.gz"
        );
        assert_eq!(
            archive_url("https://github.com/O/R/", "dev"),
            "https://github.com/O/R/archive/refs/heads/dev.tar.gz"
        );
    }

    #[test]
    fn github_repositories_are_read_from_their_url() {
        assert_eq!(
            github_repo("https://github.com/SavageDuck26/Ducks-Gauntlet-Mods.git").as_deref(),
            Some("SavageDuck26/Ducks-Gauntlet-Mods")
        );
        assert_eq!(github_repo("https://github.com/O/R/").as_deref(), Some("O/R"));

        // Anything the API cannot answer for is refused rather than guessed at.
        assert_eq!(github_repo("https://example.invalid/O/R.git"), None);
        assert_eq!(github_repo("https://github.com/O"), None);
        assert_eq!(github_repo("https://github.com/O/R/tree/main"), None);
    }

    #[test]
    fn the_commit_sha_is_read_out_of_the_refs_answer() {
        let json = r#"{
          "ref": "refs/heads/main",
          "node_id": "MDM6UmVm",
          "url": "https://api.github.com/repos/O/R/git/refs/heads/main",
          "object": {
            "sha": "3f8a0c9d2b7e6f5a4c3b2a190817263544556677",
            "type": "commit",
            "url": "https://api.github.com/repos/O/R/git/commits/3f8a0c9d2b7e6f5a4c3b2a190817263544556677"
          }
        }"#;

        assert_eq!(
            sha_from_json(json).as_deref(),
            Some("3f8a0c9d2b7e6f5a4c3b2a190817263544556677")
        );
        assert_eq!(sha_from_json("{}"), None);
        assert_eq!(sha_from_json(r#"{"sha": "not-a-commit"}"#), None);
    }

    /// The pull mechanism in a temp folder, with a local server standing in for GitHub: the first
    /// pull unpacks and records the commit, the same commit costs no download, and a new commit
    /// replaces the copy wholesale.
    #[test]
    fn a_new_commit_is_downloaded_and_swapped_in() {
        let root = temp_root("ducksmm_pack_refresh");
        let pack_dir = root.join("pack");
        let first = root.join("first.tar.gz");
        let second = root.join("second.tar.gz");

        tarball(
            &first,
            &[("Pack-main/Mods/script.lua", "-- one")],
            None,
            None,
        );
        tarball(
            &second,
            &[("Pack-main/Mods/script.lua", "-- two")],
            None,
            None,
        );

        let server = crate::testserver::TestServer::serve(vec![
            (
                "/first.tar.gz",
                fs::read(&first).expect("read the first archive"),
            ),
            (
                "/second.tar.gz",
                fs::read(&second).expect("read the second archive"),
            ),
        ]);
        let first_url = format!("{}/first.tar.gz", server.base());
        let second_url = format!("{}/second.tar.gz", server.base());

        let Refreshed::Changed { version } =
            refresh_to(&pack_dir, "commit-one", &first_url).expect("first pull")
        else {
            panic!("the first pull must install the pack");
        };
        assert_eq!(version, "commit-one");
        assert_eq!(version_of(&pack_dir).as_deref(), Some("commit-one"));
        assert_eq!(
            fs::read_to_string(pack_dir.join("Mods").join("script.lua")).unwrap(),
            "-- one"
        );

        // The same commit is already on disk, so the archive is not fetched again.
        assert!(matches!(
            refresh_to(&pack_dir, "commit-one", &first_url).expect("unchanged pull"),
            Refreshed::Unchanged { .. }
        ));

        // A new commit replaces the copy, so the old file is gone rather than merged.
        assert!(matches!(
            refresh_to(&pack_dir, "commit-two", &second_url).expect("second pull"),
            Refreshed::Changed { .. }
        ));
        assert_eq!(version_of(&pack_dir).as_deref(), Some("commit-two"));
        assert_eq!(
            fs::read_to_string(pack_dir.join("Mods").join("script.lua")).unwrap(),
            "-- two"
        );

        fs::remove_dir_all(&root).ok();
    }

    #[test]
    fn unpack_writes_files_and_folders() {
        let root = temp_root("ducksmm_pack_unpack");
        let archive = root.join("pack.tar.gz");
        let out = empty_dir(&root);

        tarball(&archive, &[("Pack-main/Mods/script.lua", "-- hi")], None, None);
        unpack(&archive, &out).expect("unpack");

        assert_eq!(
            text(&read_tree(&out.join("Pack-main/Mods")), "script.lua"),
            "-- hi"
        );

        fs::remove_dir_all(&root).ok();
    }

    /// A `..` entry would write outside the folder being unpacked into.
    #[test]
    fn unpack_refuses_paths_that_leave_the_folder() {
        let root = temp_root("ducksmm_pack_escape");
        let archive = root.join("pack.tar.gz");
        let out = empty_dir(&root);

        tarball(&archive, &[], Some("../outside.lua"), None);

        assert!(unpack(&archive, &out).is_err());
        assert!(!root.join("outside.lua").exists());

        fs::remove_dir_all(&root).ok();
    }

    /// The `tar` crate would happily create a symlink; a mods folder has no use for one.
    #[test]
    fn unpack_refuses_links() {
        let root = temp_root("ducksmm_pack_link");
        let archive = root.join("pack.tar.gz");
        let out = empty_dir(&root);

        tarball(&archive, &[], None, Some("link.lua"));

        assert!(unpack(&archive, &out).is_err());

        fs::remove_dir_all(&root).ok();
    }

    #[test]
    fn fingerprints_follow_content() {
        let one: Tree = [("a.lua".to_owned(), b"x".to_vec())].into_iter().collect();
        let same: Tree = [("a.lua".to_owned(), b"x".to_vec())].into_iter().collect();
        let changed: Tree = [("a.lua".to_owned(), b"y".to_vec())].into_iter().collect();
        let added: Tree = [
            ("a.lua".to_owned(), b"x".to_vec()),
            ("b.lua".to_owned(), Vec::new()),
        ]
        .into_iter()
        .collect();

        assert_eq!(fingerprint(&one), fingerprint(&same));
        assert_ne!(fingerprint(&one), fingerprint(&changed));
        assert_ne!(fingerprint(&one), fingerprint(&added));
        assert_eq!(fingerprint(&one).len(), 16);
    }

    /// End to end against the real remote, the way the Pull button does it: download the branch,
    /// unpack it, scan it, install a mod out of it, pull again and expect nothing to do, then check
    /// that a leftover from an older layout is pruned by the next pull.
    ///
    /// Ignored because it needs the network. Run it with:
    ///
    /// ```text
    /// cargo test live_pull -- --ignored --nocapture
    /// ```
    #[test]
    #[ignore]
    fn live_pull_round_trip() {
        let root = temp_root("ducksmm_live_pull");
        let pack_dir = root.join("pack");
        let installs = root.join("Ducks Mods");
        let repo = "https://github.com/SavageDuck26/Ducks-Gauntlet-Mods.git";

        // 1. Check, download and unpack, twice: the second finds the same commit, so the archive is
        //    not fetched or unpacked again.
        match refresh(&pack_dir, repo, "main").expect("first refresh") {
            Refreshed::Changed { version } => println!("pack version {version}"),
            Refreshed::Unchanged { .. } => panic!("the first refresh cannot find nothing to do"),
        }
        assert!(
            matches!(
                refresh(&pack_dir, repo, "main").expect("second refresh"),
                Refreshed::Unchanged { .. }
            ),
            "an unchanged pack should not be unpacked again"
        );

        // 2. The scan: categories, never the folder the repo wraps the pack in.
        let paths: Vec<String> = mods(&pack_dir).iter().map(PackMod::rel_path).collect();
        println!("{} mods found: {paths:?}", paths.len());

        assert!(!paths.is_empty(), "the pack should hold mods");
        assert!(
            paths.iter().any(|path| path == "AddUtility(REQUIRED_FOR_MODS)"),
            "the required mod should be found at the top of the pack"
        );
        assert!(
            paths.iter().any(|path| path.starts_with("Local Mods/")),
            "categories below the wrapper should be found"
        );
        assert!(
            paths.iter().all(|path| !path.starts_with("Ducks-Modpack")),
            "the wrapper leaked into a mod path: {paths:?}"
        );

        // 3. A pull: install one mod, then pull again with the pack's version as the base, exactly as
        //    `update_one` does.
        let rel = "Local Mods/DucksUI";
        let theirs = read_tree(&locate(&pack_dir, rel));
        assert!(!theirs.is_empty(), "{rel} should be in the pack copy");

        let first = crate::install::update(None, &theirs, &installs.join(rel)).expect("install it");
        println!("first pull: {} written, {} removed", first.written, first.deleted);
        assert!(first.written > 0, "a fresh install should write files");

        let second =
            crate::install::update(Some(&theirs), &theirs, &installs.join(rel)).expect("pull again");
        assert!(
            second.quiet(),
            "pulling an up-to-date mod should do nothing, got {} written, {} removed, {} conflicts",
            second.written,
            second.deleted,
            second.conflicts.len()
        );

        // 4. A file left over from an older layout is pruned by the next pull.
        let leftover = installs.join(rel).join("Ducks Mods").join("script_stale.lua");
        fs::create_dir_all(leftover.parent().unwrap()).expect("create the leftover's folder");
        fs::write(&leftover, "-- stale").expect("write the leftover");

        let third =
            crate::install::update(Some(&theirs), &theirs, &installs.join(rel)).expect("pull again");
        println!("pruning pull: {} written, {} removed", third.written, third.deleted);
        assert_eq!(third.deleted, 1, "the leftover should be the only thing removed");
        assert!(!leftover.exists(), "the leftover should be gone");

        fs::remove_dir_all(&root).ok();
    }
}

