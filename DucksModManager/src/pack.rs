//! The manager's own copy of the pack.
//!
//! There is no git here on purpose. The pack is fetched as a plain HTTPS download of GitHub's
//! archive of the branch, and unpacked with `tar`/`flate2`; the release assets are the same story
//! with `zip`. That means one small HTTP crate instead of a git implementation, no git, ssh or gh
//! on the player's machine, and the Mozilla roots compiled into the binary by ureq's own rustls
//! setup, so nothing depends on the system certificate store.
//!
//! What a snapshot costs us is history: there is no commit to diff against, so a mod's version is
//! identified by a fingerprint of its files instead. That is all `install.rs` ever needed.
//!
//! Everything in here is about getting the pack onto disk and reading it. Deciding what to do with
//! the files is `install.rs`'s job.

use std::collections::BTreeMap;
use std::fs;
use std::path::{Component, Path, PathBuf};

use sha2::{Digest, Sha256};

/// Folder inside the manager's appdata holding the pack copy.
pub const PACK_DIR: &str = "pack";

/// Where the fingerprint of the pack copy on disk is kept, so the next check can tell whether the
/// pack has moved on.
pub const VERSION_FILE: &str = "pack.version";

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

/// Opens the pack copy, cloning it first if this is the first run.
/// because it only holds folders, so its children are the mods.
/// GitHub's archive of a branch, which is what the manager downloads. Public, no API and no token,
/// and it redirects to codeload — which ureq follows.
pub fn archive_url(repo_url: &str, branch: &str) -> String {
    let base = repo_url.trim_end_matches('/');
    let base = base.strip_suffix(".git").unwrap_or(base);
    format!("{base}/archive/refs/heads/{branch}.tar.gz")
}

/// Downloads `url` to `dest`, streamed, so even a large archive never sits in memory.
pub fn download(url: &str, dest: &Path) -> Result<(), String> {
    let mut response = ureq::get(url).call().map_err(|err| err.to_string())?;
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

pub fn mods(root: &Path) -> Vec<PackMod> {
    let mut found = Vec::new();

    for folder in folders(root) {
        // The category is the top-level folder, whether the mod turns out to be that folder itself
        // or one of its children.
        let category = file_name(&folder);
        collect_mods(&folder, &category, &mut found);
    }

    found.sort_by_key(PackMod::rel_path);
    found
}

/// Reads a folder from disk into a [`Tree`], keyed by path relative to `dir`.
pub fn read_tree(dir: &Path) -> Tree {
    let mut tree = Tree::new();
    read_disk_into(dir, "", &mut tree);
    tree
}

/// Reads one mod folder out of the pack's history: how it looked at `commit`.
/// Walks down until it reaches a folder holding a `.lua` directly; that folder is the mod.
fn collect_mods(dir: &Path, category: &str, found: &mut Vec<PackMod>) {
    if holds_lua(dir) {
        found.push(PackMod {
            category: category.to_owned(),
            name: file_name(dir),
        });
        return;
    }

    for child in folders(dir) {
        collect_mods(&child, category, found);
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

/// Fetches the pack if it has changed, and reports its version either way.
///
/// The download is hashed first, so an unchanged pack costs one request and nothing else. A changed
/// one is unpacked into a fresh folder and only then swapped in, so a failed download or a
/// half-written unpack can never leave the pack copy in pieces.
pub fn refresh(pack_dir: &Path, url: &str) -> Result<Refreshed, String> {
    let archive = pack_dir.with_extension("download");
    download(url, &archive)?;

    let version = fingerprint_file(&archive)?;
    if version_of(pack_dir).as_deref() == Some(version.as_str()) && pack_dir.is_dir() {
        fs::remove_file(&archive).ok();
        return Ok(Refreshed::Unchanged { version });
    }

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

    write_version(pack_dir, &version)?;
    Ok(Refreshed::Changed { version })
}

/// The version of the pack copy on disk, if it has one.
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

fn fingerprint_file(path: &Path) -> Result<String, String> {
    let bytes = fs::read(path).map_err(|err| err.to_string())?;
    let mut hasher = Sha256::new();
    hasher.update(&bytes);

    Ok(short_hex(&hasher.finalize()))
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
        write_file(&root.join("Docs (READ ME PLEASE)").join("Local Mods.md"), "docs");

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
}

