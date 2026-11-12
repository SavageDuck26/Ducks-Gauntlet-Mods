//! Keeping the manager itself up to date.
//!
//! The pack is versioned by its commit; the manager is versioned by its own bytes. The newest
//! release's binary is downloaded, hashed, and compared against the hash of the executable that is
//! running — the same file means there is nothing to do, a different one is the update. No version
//! file and no published checksum list are involved: the release *is* the source of truth.
//!
//! There is no GitHub API here and no token: `/releases/latest/download/<asset>` is a plain
//! redirect to the newest published release's file. Drafts are invisible to that URL.
//!
//! A running executable cannot be written over — Windows locks it, and on Linux the running image
//! *is* the file. What works on both is the rename dance: move the running executable aside, move
//! the downloaded one into its place, start that, and leave the old file to be deleted on the next
//! launch. [`install_at`] is that dance with the folder and executable passed in, which is how the
//! tests exercise it against a temp directory.

use std::fs;
use std::path::{Path, PathBuf};
use std::time::Duration;

use sha2::{Digest, Sha256};

/// The folder `/releases/latest/download` — where the newest published release's files live.
pub const RELEASES: &str =
    "https://github.com/SavageDuck26/Ducks-Gauntlet-Mods/releases/latest/download";

/// The version compiled into this build, for display. Updates are decided by hash, not by this.
pub const CURRENT_VERSION: &str = env!("CARGO_PKG_VERSION");

/// The file this build replaces. Every release publishes exactly these names, so the two platforms
/// that `dist/` ships can never take each other's update.
pub const ASSET: &str = if cfg!(windows) {
    "DucksModManager-windows-x86_64.exe"
} else {
    "DucksModManager-linux-x86_64"
};

/// ureq has every timeout switched off by default, and the check runs before the window is first
/// drawn. The binary gets long enough that even a slow line can finish downloading it.
const DOWNLOAD_TIMEOUT: Duration = Duration::from_secs(120);

/// What the last check found.
#[derive(Clone, Default, PartialEq, Eq)]
pub enum Status {
    /// Nothing has been checked yet.
    #[default]
    Unknown,
    /// The running executable is byte-for-byte the newest release, or there is no release yet.
    UpToDate,
    /// The newest release is a different build.
    Available { digest: String },
    /// The check could not be made.
    Failed(String),
}

/// The newest release, as found by [`check`]. It has already been downloaded and staged beside the
/// executable, so installing it does not fetch it a second time.
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct Release {
    /// SHA-256 of the staged file, which is what told it apart from the running build.
    pub digest: String,
}

impl Release {
    /// The first characters of the hash: enough to tell one release from another by eye.
    pub fn short(&self) -> &str {
        &self.digest[..self.digest.len().min(8)]
    }
}

/// Downloads the newest release and compares it with the executable that is running. `Ok(None)`
/// covers "already up to date" and "no release published yet": neither needs action.
pub fn check() -> Result<Option<Release>, String> {
    let exe = std::env::current_exe().map_err(|err| format!("cannot find this executable: {err}"))?;
    check_at(&exe, RELEASES)
}

/// [`check`] with the executable and release folder given, so the tests can point both at tmp.
fn check_at(exe: &Path, releases: &str) -> Result<Option<Release>, String> {
    if exe.parent().is_none() {
        return Err("the executable has no folder to update in".to_owned());
    }

    let staged = sidecar(exe, "new");
    fs::remove_file(&staged).ok();
    match download(&file_url(releases, ASSET), &staged) {
        Ok(()) => {}
        // No release published yet: nothing to install, and not something the player must act on.
        Err(Problem::Missing) => return Ok(None),
        Err(Problem::Failed(message)) => return Err(message),
    }

    let digest = sha256_file(&staged)?;
    if digest == sha256_file(exe)? {
        // The same file as the one running: nothing to install, and nothing to keep.
        fs::remove_file(&staged).ok();
        return Ok(None);
    }

    Ok(Some(Release { digest }))
}

/// Swaps the staged release in and starts it.
///
/// The replacement is started before this process is left to exit, so a file that cannot run is
/// undone and the old manager is put back. The caller only has to close its window; the previous
/// build's file is cleaned up by [`cleanup`] on the next launch.
pub fn install(release: &Release) -> Result<PathBuf, String> {
    let exe = std::env::current_exe().map_err(|err| format!("cannot find this executable: {err}"))?;
    let exe = install_at(&exe, RELEASES, release)?;

    if let Err(err) = std::process::Command::new(&exe).spawn() {
        // Undo the swap, so the next launch is the build that works rather than one that cannot.
        let staged = sidecar(&exe, "new");
        let old = sidecar(&exe, "old");
        fs::rename(&exe, &staged).ok();
        fs::rename(&old, &exe).ok();
        return Err(format!("the new manager could not start: {err}"));
    }

    Ok(exe)
}

/// The verify and swap, with the executable and release folder given. The tests drive this against
/// a temp directory, which is how the rename dance is checked without touching the real binary.
fn install_at(exe: &Path, releases: &str, release: &Release) -> Result<PathBuf, String> {
    if exe.parent().is_none() {
        return Err("the executable has no folder to update in".to_owned());
    }

    let staged = sidecar(exe, "new");
    let old = sidecar(exe, "old");

    // The check stages the download; only a missing file is fetched again.
    if !staged.is_file() {
        download(&file_url(releases, ASSET), &staged).map_err(|problem| match problem {
            Problem::Missing => format!("the release publishes no {ASSET}"),
            Problem::Failed(message) => message,
        })?;
    }

    // The staged file must still be the release the check saw. A file that changed under us is not
    // installed, and the working manager is left alone.
    let digest = sha256_file(&staged)?;
    if digest != release.digest {
        fs::remove_file(&staged).ok();
        return Err("the staged manager is not the release that was checked; check again".to_owned());
    }

    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(&staged, fs::Permissions::from_mode(0o755))
            .map_err(|err| format!("could not make the download executable: {err}"))?;
    }

    // Left over from an update whose replacement has since exited. It could not be deleted while
    // the old process was still running, which is exactly why it is only cleared here.
    fs::remove_file(&old).ok();

    fs::rename(exe, &old).map_err(|err| {
        format!(
            "could not move the running manager aside ({err}); if it lives in a protected folder, \
             move it somewhere writable and update again"
        )
    })?;

    if let Err(err) = fs::rename(&staged, exe) {
        // Put the old one back before reporting: a failed update must never leave nothing to run.
        fs::rename(&old, exe).ok();
        return Err(format!("could not put the new manager in place: {err}"));
    }

    Ok(exe.to_path_buf())
}

/// Clears what an earlier update left beside the executable. Called on startup: by then a replaced
/// binary is no longer running, and a download that was never swapped in is stale.
pub fn cleanup() {
    let Ok(exe) = std::env::current_exe() else {
        return;
    };

    for suffix in ["old", "new"] {
        fs::remove_file(sidecar(&exe, suffix)).ok();
    }
}

/// One file out of the release folder: `<releases>/<name>`.
fn file_url(releases: &str, name: &str) -> String {
    format!("{}/{name}", releases.trim_end_matches('/'))
}

/// Why a download did not produce a file. A 404 is kept apart because "no release yet" is an
/// ordinary state, not an error the player needs to see.
enum Problem {
    /// No release, or no such asset, has been published.
    Missing,
    Failed(String),
}

/// An HTTP agent with one deadline covering the whole request: resolve, connect, redirects and the
/// body. `ureq` ships with no timeout at all, which is not something the UI thread can afford.
fn agent(timeout: Duration) -> ureq::Agent {
    let config = ureq::Agent::config_builder()
        .timeout_global(Some(timeout))
        .build();

    ureq::Agent::new_with_config(config)
}

/// Streams `url` into `dest`, so an executable of several megabytes never sits in memory.
fn download(url: &str, dest: &Path) -> Result<(), Problem> {
    let mut response = agent(DOWNLOAD_TIMEOUT)
        .get(url)
        .call()
        .map_err(|err| match err {
            ureq::Error::StatusCode(404) => Problem::Missing,
            err => Problem::Failed(format!("could not download {url}: {err}")),
        })?;
    let mut body = response.body_mut().as_reader();

    let mut file = fs::File::create(dest).map_err(|err| {
        Problem::Failed(format!(
            "could not write {}: {err} — is the manager's folder writable?",
            dest.display()
        ))
    })?;
    std::io::copy(&mut body, &mut file)
        .map_err(|err| Problem::Failed(format!("could not save {url}: {err}")))?;

    Ok(())
}

fn sha256_file(path: &Path) -> Result<String, String> {
    use std::io::Read;

    let mut file = fs::File::open(path)
        .map_err(|err| format!("could not read {}: {err}", path.display()))?;
    let mut hasher = Sha256::new();
    let mut buffer = [0u8; 64 * 1024];

    loop {
        let read = file.read(&mut buffer).map_err(|err| err.to_string())?;
        if read == 0 {
            break;
        }
        hasher.update(&buffer[..read]);
    }

    Ok(hex(&hasher.finalize()))
}

/// The same file name with a suffix — `DucksModManager.exe.new`. It sits in the executable's own
/// folder so the final rename never crosses a filesystem, which is what keeps the swap atomic.
fn sidecar(exe: &Path, suffix: &str) -> PathBuf {
    let name = exe
        .file_name()
        .map(|name| name.to_string_lossy().into_owned())
        .unwrap_or_default();

    exe.with_file_name(format!("{name}.{suffix}"))
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|byte| format!("{byte:02x}")).collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::testserver::TestServer;

    fn temp_root(name: &str) -> PathBuf {
        let root = std::env::temp_dir().join(name);
        fs::remove_dir_all(&root).ok();
        fs::create_dir_all(&root).expect("create the test folder");
        root
    }

    fn sha(input: &[u8]) -> String {
        let mut hasher = Sha256::new();
        hasher.update(input);
        hex(&hasher.finalize())
    }

    #[test]
    fn a_file_hashes_to_what_it_contains() {
        let root = temp_root("ducksmm_selfupdate_hash");
        let path = root.join("ducks.txt");
        fs::write(&path, b"ducks").expect("write the file");

        // sha256("ducks"), as `printf ducks | sha256sum` prints it.
        assert_eq!(
            sha256_file(&path).expect("hash the file"),
            "c1bbfe449f1639e45aa3b4f75eb861e608b9e466b61da04cc256dad0e86775cb"
        );

        fs::remove_dir_all(&root).ok();
    }

    #[test]
    fn staged_files_keep_the_name_and_sit_beside_it() {
        let exe = Path::new("DucksModManager-linux-x86_64");
        assert_eq!(
            sidecar(exe, "new"),
            PathBuf::from("DucksModManager-linux-x86_64.new")
        );
        assert_eq!(
            sidecar(exe, "old"),
            PathBuf::from("DucksModManager-linux-x86_64.old")
        );
    }

    /// The whole point of the check: the newest release is downloaded and hashed, and the running
    /// build's hash decides whether that is an update.
    #[test]
    fn the_latest_release_is_compared_with_the_running_build_by_hash() {
        let root = temp_root("ducksmm_selfupdate_compare");
        let exe = root.join(ASSET);
        fs::write(&exe, b"build one").expect("write the running build");

        let same = TestServer::serve(vec![(format!("/{ASSET}"), b"build one".to_vec())]);
        assert!(check_at(&exe, same.base()).expect("check").is_none());
        assert!(
            !sidecar(&exe, "new").exists(),
            "an identical download is not kept"
        );

        let different = TestServer::serve(vec![(format!("/{ASSET}"), b"build two".to_vec())]);
        let release = check_at(&exe, different.base())
            .expect("check")
            .expect("a different release is an update");

        assert_eq!(release.digest, sha(b"build two"));
        assert!(
            sidecar(&exe, "new").is_file(),
            "the update is staged for install"
        );

        fs::remove_dir_all(&root).ok();
    }

    /// No release published yet is GitHub's 404, which must read as "nothing to do".
    #[test]
    fn no_release_published_is_not_an_error() {
        let root = temp_root("ducksmm_selfupdate_no_release");
        let exe = root.join(ASSET);
        fs::write(&exe, b"build one").expect("write the running build");

        let server = TestServer::serve(Vec::<(String, Vec<u8>)>::new());
        assert!(check_at(&exe, server.base()).expect("check").is_none());

        fs::remove_dir_all(&root).ok();
    }

    /// The swap in a temp folder: the executable becomes the downloaded build, its old self is kept
    /// beside it, and the new file is executable on Unix.
    #[test]
    fn a_new_release_is_swapped_in() {
        let root = temp_root("ducksmm_selfupdate_swap");
        let exe = root.join(ASSET);
        fs::write(&exe, b"build one").expect("write the running build");

        let server = TestServer::serve(vec![(format!("/{ASSET}"), b"build two".to_vec())]);
        let release = check_at(&exe, server.base())
            .expect("check")
            .expect("an update");

        let swapped = install_at(&exe, server.base(), &release).expect("install the release");

        assert_eq!(swapped, exe);
        assert_eq!(fs::read(&exe).expect("read the new build"), b"build two");
        assert_eq!(
            fs::read(sidecar(&exe, "old")).expect("read the old build"),
            b"build one"
        );
        assert!(!sidecar(&exe, "new").exists());

        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mode = fs::metadata(&exe)
                .expect("the new build's metadata")
                .permissions()
                .mode();
            assert_eq!(mode & 0o111, 0o111, "the new manager must be executable");
        }

        fs::remove_dir_all(&root).ok();
    }

    /// If the staged file changes after the check, it is not the release that was checked: it is
    /// discarded and the working manager stays exactly as it was.
    #[test]
    fn a_changed_stage_is_refused() {
        let root = temp_root("ducksmm_selfupdate_tampered");
        let exe = root.join(ASSET);
        fs::write(&exe, b"build one").expect("write the running build");

        let server = TestServer::serve(vec![(format!("/{ASSET}"), b"build two".to_vec())]);
        let release = check_at(&exe, server.base())
            .expect("check")
            .expect("an update");

        fs::write(sidecar(&exe, "new"), b"tampered").expect("tamper with the staged file");

        let err = install_at(&exe, server.base(), &release).expect_err("a changed stage is refused");
        assert!(err.contains("not the release"), "{err}");
        assert_eq!(fs::read(&exe).expect("read the running build"), b"build one");
        assert!(!sidecar(&exe, "new").exists());

        fs::remove_dir_all(&root).ok();
    }

    /// Ignored because it needs the network, and because what it finds depends on what has been
    /// published. Run it with:
    ///
    /// ```text
    /// cargo test live_release_check -- --ignored --nocapture
    /// ```
    #[test]
    #[ignore]
    fn live_release_check() {
        let result = check();

        // The test binary is not the manager, so nothing it staged is worth keeping.
        if let Ok(exe) = std::env::current_exe() {
            fs::remove_file(sidecar(&exe, "new")).ok();
        }

        match result {
            Ok(Some(release)) => println!("newer release: {}", release.digest),
            Ok(None) => println!("running build is the latest release, or no release exists"),
            Err(err) => panic!("the check failed: {err}"),
        }
    }
}
