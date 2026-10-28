//! Savestates: whole-folder snapshots of the installed mods, kept inside the manager's own folder.
//!
//! A savestate is a plain copy of the mod install — no compression, no diffs, nothing fancy. It is
//! deliberately not git: the manager has to work on machines that have never had git installed, so
//! a snapshot is something the player can open, copy or delete in their own file browser.
//!
//! Layout, under `<mods folder>/DucksModManager/savestate/`:
//!
//! ```text
//! 2026-10-26_031610/       the snapshot: the mod install as it was
//! 2026-10-26_031610.conf   what it was taken from, and why
//! ```
//!
// The UI drives `create`, `restore` and `overwrite`. `remove` is written and tested but no button
// asks for it yet — the savestate browser is the next step — so unused warnings are silenced for
// the whole module.
#![allow(dead_code)]

use std::fs;
use std::io;
use std::io::Write;
use std::path::{Path, PathBuf};

use zip::write::SimpleFileOptions;
use zip::{CompressionMethod, ZipArchive, ZipWriter};

/// Folder inside the manager's appdata where snapshots live.
pub const SAVESTATE_DIR: &str = "savestate";

/// Suffix of the small file describing a snapshot.
const INFO_SUFFIX: &str = ".conf";

/// Savestates are zip archives: one file per snapshot instead of a folder tree.
const ARCHIVE_SUFFIX: &str = ".zip";

/// One snapshot on disk.
pub struct Savestate {
    /// Folder name, e.g. `2026-10-26_031610`.
    pub stamp: String,
    /// Where the copy lives.
    pub path: PathBuf,
    /// The folder it was copied from.
    pub source: String,
    /// Why it was taken, e.g. `before pulling an update`.
    pub label: String,
}

/// Zips `source` into a fresh savestate and returns the name it was given.
///
/// `name` is what the player typed. When that is empty the savestate is named after the date and
/// time, which is what it has always been.
pub fn create(root: &Path, source: &Path, name: &str, label: &str) -> Result<String, String> {
    fs::create_dir_all(root).map_err(|err| err.to_string())?;

    let stamp = free_name(root, name);
    let file = fs::File::create(archive_path(root, &stamp)).map_err(|err| err.to_string())?;
    let mut zip = ZipWriter::new(file);

    write_tree(&mut zip, source, "")?;
    zip.finish().map_err(|err| err.to_string())?;

    write_info(root, &stamp, source, label).map_err(|err| err.to_string())?;
    Ok(stamp)
}

/// Replaces an existing savestate with the mods as they are now, keeping its name.
///
/// [`create`] deliberately never reuses a name, so taking a savestate always adds one. This is the
/// other half of that: the player picked a savestate and asked for it to catch up, so its archive
/// is rewritten in place. It cannot be undone, so the UI says so before calling this.
pub fn overwrite(root: &Path, stamp: &str, source: &Path, label: &str) -> Result<(), String> {
    let archive = archive_path(root, stamp);
    if !archive.is_file() {
        return Err(format!("there is no savestate called {stamp}"));
    }

    // Written beside the old archive and renamed over it, so a failure part way through — a full
    // disk, a file being read — leaves the savestate that is there untouched.
    let staging = root.join(format!("{stamp}.partial"));
    fs::remove_file(&staging).ok();

    let file = fs::File::create(&staging).map_err(|err| err.to_string())?;
    let written = {
        let mut zip = ZipWriter::new(file);
        write_tree(&mut zip, source, "")
            .and_then(|()| zip.finish().map(|_| ()).map_err(|err| err.to_string()))
    };
    if let Err(err) = written {
        fs::remove_file(&staging).ok();
        return Err(err);
    }

    if let Err(err) = fs::rename(&staging, &archive) {
        fs::remove_file(&staging).ok();
        return Err(err.to_string());
    }

    write_info(root, stamp, source, label).map_err(|err| err.to_string())
}

/// Adds every file under `dir` to the archive, keyed by its path inside the savestate.
fn write_tree(zip: &mut ZipWriter<fs::File>, dir: &Path, prefix: &str) -> Result<(), String> {
    let options = SimpleFileOptions::default().compression_method(CompressionMethod::Deflated);

    for entry in fs::read_dir(dir).into_iter().flatten().flatten() {
        let name = entry.file_name().to_string_lossy().into_owned();
        let path = if prefix.is_empty() {
            name
        } else {
            format!("{prefix}/{name}")
        };
        let Ok(kind) = entry.file_type() else {
            continue;
        };

        if kind.is_dir() {
            write_tree(zip, &entry.path(), &path)?;
        } else if kind.is_file() {
            let bytes = fs::read(entry.path()).map_err(|err| err.to_string())?;
            zip.start_file(&path, options).map_err(|err| err.to_string())?;
            zip.write_all(&bytes).map_err(|err| err.to_string())?;
        }
        // Symlinks are skipped: a mods folder is plain files, and following one could pull in
        // something from well outside the pack.
    }

    Ok(())
}

/// Unpacks a savestate over `target`, which is replaced by whatever the archive holds.
pub fn restore(root: &Path, stamp: &str, target: &Path) -> Result<(), String> {
    let file = fs::File::open(archive_path(root, stamp))
        .map_err(|_| format!("there is no savestate called {stamp}"))?;
    let mut zip = ZipArchive::new(file).map_err(|err| err.to_string())?;

    if target.exists() {
        fs::remove_dir_all(target).map_err(|err| err.to_string())?;
    }
    fs::create_dir_all(target).map_err(|err| err.to_string())?;

    for index in 0..zip.len() {
        let mut entry = zip.by_index(index).map_err(|err| err.to_string())?;

        // `enclosed_name` is the crate's own guard: it gives nothing back for an entry that tries to
        // leave the folder, which is exactly what must never be written.
        let Some(relative) = entry.enclosed_name() else {
            let name = entry.name().unwrap_or_default().into_owned();
            return Err(format!("refusing to restore {name}"));
        };
        let out = target.join(relative);

        if entry.is_dir() {
            fs::create_dir_all(&out).map_err(|err| err.to_string())?;
        } else if entry.is_file() {
            if let Some(parent) = out.parent() {
                fs::create_dir_all(parent).map_err(|err| err.to_string())?;
            }
            let mut file = fs::File::create(&out).map_err(|err| err.to_string())?;
            std::io::copy(&mut entry, &mut file).map_err(|err| err.to_string())?;
        }
        // Anything that is neither a file nor a folder has no place in a mods folder.
    }

    Ok(())
}

/// Every savestate under `root`, newest first. A missing folder just means there are none yet.
pub fn list(root: &Path) -> Vec<Savestate> {
    let Ok(entries) = fs::read_dir(root) else {
        return Vec::new();
    };

    let mut states: Vec<Savestate> = entries
        .flatten()
        .filter(|entry| entry.file_type().is_ok_and(|kind| kind.is_file()))
        .filter_map(|entry| {
            let file_name = entry.file_name().to_string_lossy().into_owned();
            let stamp = file_name.strip_suffix(ARCHIVE_SUFFIX)?.to_owned();
            let (source, label) = read_info(root, &stamp);
            Some(Savestate {
                path: entry.path(),
                stamp,
                source,
                label,
            })
        })
        .collect();

    // Dated names sort as text, so this puts the newest first. Named savestates sort after them,
    // which is the useful way round: the date is what "the latest one" means.
    states.sort_by(|a, b| b.stamp.cmp(&a.stamp));
    states
}

/// Deletes one savestate, archive and description together.
pub fn remove(root: &Path, stamp: &str) -> Result<(), String> {
    let archive = archive_path(root, stamp);
    if archive.is_file() {
        fs::remove_file(&archive).map_err(|err| err.to_string())?;
    }

    let info = info_path(root, stamp);
    if info.is_file() {
        fs::remove_file(info).map_err(|err| err.to_string())?;
    }

    Ok(())
}

fn archive_path(root: &Path, stamp: &str) -> PathBuf {
    root.join(format!("{stamp}{ARCHIVE_SUFFIX}"))
}

/// The name a new savestate gets: what the player typed, tidied into something a filesystem will
/// take, or the date and time when they typed nothing.
fn savestate_name(name: &str) -> String {
    let cleaned: String = name
        .trim()
        .chars()
        .map(|letter| {
            if "\\/:*?\"<>|".contains(letter) {
                '-'
            } else {
                letter
            }
        })
        .take(60)
        .collect();
    let cleaned = cleaned.trim();

    if cleaned.is_empty() {
        stamp_now()
    } else {
        cleaned.to_owned()
    }
}

/// A name that is not taken yet, so taking a savestate never overwrites an older one.
fn free_name(root: &Path, name: &str) -> String {
    let wanted = savestate_name(name);
    let mut candidate = wanted.clone();
    let mut suffix = 2;

    while archive_path(root, &candidate).exists() {
        candidate = format!("{wanted}_{suffix}");
        suffix += 1;
    }

    candidate
}


/// Flattens a value so it cannot break a line-based file. The settings and savestate files are both
/// one `key = value` per line, and both go through here.
pub fn one_line(value: &str) -> String {
    value.replace(['\n', '\r'], " ")
}

/// Folder-friendly UTC stamp, `2026-10-26_031610`. Savestates get browsed by hand, so the name has
/// to say when it was taken.
fn stamp_now() -> String {
    let seconds = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|elapsed| elapsed.as_secs())
        .unwrap_or(0);

    stamp_from_unix(seconds)
}

/// Formats Unix seconds as UTC. There is no date crate in the build and one is not worth adding for
/// a folder name, so the calendar date is worked out from the day count directly.
fn stamp_from_unix(seconds: u64) -> String {
    let days = (seconds / 86_400) as i64;
    let time = seconds % 86_400;
    let (year, month, day) = civil_from_days(days);

    format!(
        "{year:04}-{month:02}-{day:02}_{:02}{:02}{:02}",
        time / 3600,
        (time % 3600) / 60,
        time % 60
    )
}

/// Howard Hinnant's `civil_from_days`: days since the Unix epoch to a calendar date.
fn civil_from_days(days: i64) -> (i64, u32, u32) {
    let shifted = days + 719_468;
    let era = if shifted >= 0 {
        shifted
    } else {
        shifted - 146_096
    } / 146_097;
    let day_of_era = (shifted - era * 146_097) as u64;
    let year_of_era =
        (day_of_era - day_of_era / 1460 + day_of_era / 36_524 - day_of_era / 146_096) / 365;
    let year = year_of_era as i64 + era * 400;
    let day_of_year = day_of_era - (365 * year_of_era + year_of_era / 4 - year_of_era / 100);
    let shifted_month = (5 * day_of_year + 2) / 153;
    let day = (day_of_year - (153 * shifted_month + 2) / 5 + 1) as u32;
    let month = (if shifted_month < 10 {
        shifted_month + 3
    } else {
        shifted_month - 9
    }) as u32;

    (if month <= 2 { year + 1 } else { year }, month, day)
}

fn info_path(root: &Path, stamp: &str) -> PathBuf {
    root.join(format!("{stamp}{INFO_SUFFIX}"))
}

/// The description is a few `key = value` lines, the same style as the settings file.
fn write_info(root: &Path, stamp: &str, source: &Path, label: &str) -> io::Result<()> {
    let mut text = String::from("# Ducks Mod Manager savestate. Safe to delete.\n");
    text.push_str(&format!("stamp = {stamp}\n"));
    text.push_str(&format!(
        "source = {}\n",
        one_line(&source.display().to_string())
    ));
    text.push_str(&format!("label = {}\n", one_line(label)));

    fs::write(info_path(root, stamp), text)
}

/// Reads a description back as `(source, label)`. A missing or unreadable file reads as empty.
fn read_info(root: &Path, stamp: &str) -> (String, String) {
    let mut source = String::new();
    let mut label = String::new();

    let Ok(text) = fs::read_to_string(info_path(root, stamp)) else {
        return (source, label);
    };

    for line in text.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let Some((key, value)) = line.split_once('=') else {
            continue;
        };
        match key.trim() {
            "source" => source = value.trim().to_owned(),
            "label" => label = value.trim().to_owned(),
            _ => {}
        }
    }

    (source, label)
}

#[cfg(test)]
mod tests {
    use super::*;

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

    /// `<install>/Local Mods/<name>/script.lua`, the shape every real mod has.
    fn mod_script(install: &Path, name: &str) -> PathBuf {
        install.join("Local Mods").join(name).join("script.lua")
    }

    /// `<install>/AddUtility/script_main.lua`, the pack's one required mod.
    fn utility_script(install: &Path) -> PathBuf {
        install.join("AddUtility").join("script_main.lua")
    }

    /// A mod install with nested folders, so the archive has something real to hold.
    fn sample_install(root: &Path) -> PathBuf {
        let install = root.join("Ducks Mods");
        write_file(&utility_script(&install), "-- utility");
        write_file(&mod_script(&install, "DucksUI"), "-- ui");
        install
    }

    #[test]
    fn create_zips_the_whole_tree() {
        let root = temp_root("ducksmm_saver_create");
        let install = sample_install(&root);
        let states = root.join(SAVESTATE_DIR);

        let stamp = create(&states, &install, "", "test").expect("create a savestate");
        assert!(states.join(format!("{stamp}.zip")).is_file());

        // Restoring into an empty folder has to give the same files back.
        let elsewhere = root.join("restored");
        restore(&states, &stamp, &elsewhere).expect("restore");
        assert_eq!(
            fs::read_to_string(utility_script(&elsewhere)).unwrap(),
            "-- utility"
        );
        assert_eq!(
            fs::read_to_string(mod_script(&elsewhere, "DucksUI")).unwrap(),
            "-- ui"
        );

        fs::remove_dir_all(&root).ok();
    }

    /// A name the player typed is used, and taking the same name twice keeps both.
    #[test]
    fn a_name_is_used_when_one_is_given() {
        let root = temp_root("ducksmm_saver_name");
        let install = sample_install(&root);
        let states = root.join(SAVESTATE_DIR);

        let stamp = create(&states, &install, "before the big pull", "test").expect("create");
        assert_eq!(stamp, "before the big pull");
        assert!(states.join("before the big pull.zip").is_file());

        let again = create(&states, &install, "before the big pull", "test").expect("create again");
        assert_eq!(again, "before the big pull_2");

        fs::remove_dir_all(&root).ok();
    }

    /// An empty name falls back to the date, and an awkward one is tidied rather than refused.
    #[test]
    fn names_are_tidied_into_filenames() {
        assert_eq!(savestate_name("  before/after  "), "before-after");
        assert_eq!(savestate_name("a:b*c?"), "a-b-c-");
        assert_eq!(savestate_name("   ").len(), 17);
    }

    #[test]
    fn info_records_source_and_label() {
        let root = temp_root("ducksmm_saver_info");
        let install = sample_install(&root);
        let states = root.join(SAVESTATE_DIR);

        let stamp = create(&states, &install, "", "before pulling an update").expect("create");
        let listed = list(&states);

        assert_eq!(listed.len(), 1);
        assert_eq!(listed[0].stamp, stamp);
        assert_eq!(listed[0].label, "before pulling an update");
        assert_eq!(listed[0].source, install.display().to_string());

        fs::remove_dir_all(&root).ok();
    }

    #[test]
    fn list_is_newest_first() {
        let root = temp_root("ducksmm_saver_list");
        let install = sample_install(&root);
        let states = root.join(SAVESTATE_DIR);

        let older = create(&states, &install, "", "first").expect("create the first");
        let newer = create(&states, &install, "", "second").expect("create the second");
        let listed = list(&states);

        assert_eq!(listed.len(), 2);
        assert_eq!(listed[0].stamp, newer);
        assert_eq!(listed[1].stamp, older);

        fs::remove_dir_all(&root).ok();
    }

    #[test]
    fn restore_replaces_the_current_install() {
        let root = temp_root("ducksmm_saver_restore");
        let install = sample_install(&root);
        let states = root.join(SAVESTATE_DIR);

        let stamp = create(&states, &install, "", "before the change").expect("create");

        // Wreck the install the way a bad pull would.
        let script = mod_script(&install, "DucksUI");
        fs::remove_dir_all(install.join("AddUtility")).expect("remove a mod");
        write_file(&script, "-- edited");

        restore(&states, &stamp, &install).expect("restore");

        assert!(utility_script(&install).is_file());
        assert_eq!(fs::read_to_string(&script).unwrap(), "-- ui");

        fs::remove_dir_all(&root).ok();
    }

    /// Overwriting brings the named savestate up to date rather than adding another one: the list
    /// is the same length afterwards, and the name is the one that was asked for.
    #[test]
    fn overwrite_replaces_the_named_savestate() {
        let root = temp_root("ducksmm_saver_overwrite");
        let install = sample_install(&root);
        let states = root.join(SAVESTATE_DIR);

        let stamp = create(&states, &install, "second try", "by hand").expect("create");

        // Change the install, then bring the savestate up to date with it.
        write_file(&mod_script(&install, "DucksUI"), "-- ui, edited");
        overwrite(&states, &stamp, &install, "by hand").expect("overwrite");

        let listed = list(&states);
        assert_eq!(listed.len(), 1, "overwriting must not add a second savestate");
        assert_eq!(listed[0].stamp, stamp);
        assert!(!states.join(format!("{stamp}.partial")).exists());

        let elsewhere = root.join("restored");
        restore(&states, &stamp, &elsewhere).expect("restore");
        assert_eq!(
            fs::read_to_string(mod_script(&elsewhere, "DucksUI")).unwrap(),
            "-- ui, edited"
        );

        fs::remove_dir_all(&root).ok();
    }

    /// There is nothing to rewrite when the name is not there, and saying so is better than writing
    /// a savestate under a name the player did not ask for.
    #[test]
    fn overwriting_a_missing_savestate_fails() {
        let root = temp_root("ducksmm_saver_overwrite_missing");
        let install = sample_install(&root);
        let states = root.join(SAVESTATE_DIR);
        fs::create_dir_all(&states).expect("create the savestate folder");

        assert!(overwrite(&states, "nope", &install, "by hand").is_err());

        fs::remove_dir_all(&root).ok();
    }

    #[test]
    fn restore_of_a_missing_savestate_fails() {
        let root = temp_root("ducksmm_saver_missing");
        let states = root.join(SAVESTATE_DIR);

        assert!(restore(&states, "nope", &root.join("Ducks Mods")).is_err());

        fs::remove_dir_all(&root).ok();
    }

    #[test]
    fn remove_takes_the_archive_and_its_description() {
        let root = temp_root("ducksmm_saver_remove");
        let install = sample_install(&root);
        let states = root.join(SAVESTATE_DIR);

        let stamp = create(&states, &install, "", "test").expect("create");
        remove(&states, &stamp).expect("remove");

        assert!(!states.join(format!("{stamp}.zip")).exists());
        assert!(!states.join(format!("{stamp}.conf")).exists());
        assert!(list(&states).is_empty());

        fs::remove_dir_all(&root).ok();
    }

    /// The savestate folder sits beside the mod install, never inside it, so an archive can never
    /// end up holding the folder it is being written into.
    #[test]
    fn savestates_do_not_contain_themselves() {
        let root = temp_root("ducksmm_saver_sibling");
        let install = sample_install(&root);
        let states = root.join("DucksModManager").join(SAVESTATE_DIR);

        let stamp = create(&states, &install, "", "test").expect("create");
        let file = fs::File::open(states.join(format!("{stamp}.zip"))).expect("open the archive");
        let mut zip = ZipArchive::new(file).expect("read the archive");

        for index in 0..zip.len() {
            let entry = zip.by_index(index).expect("an entry");
            assert!(!entry.name().unwrap_or_default().contains("DucksModManager"));
        }

        fs::remove_dir_all(&root).ok();
    }

    /// The names are what the player browses, so the date has to be right. These values are checked
    /// against `date -u -d @<seconds>`.
    #[test]
    fn stamps_are_readable_utc() {
        assert_eq!(stamp_from_unix(0), "1970-01-01_000000");
        assert_eq!(stamp_from_unix(86_400), "1970-01-02_000000");
        assert_eq!(stamp_from_unix(1_700_000_000), "2023-11-14_221320");
    }

    #[test]
    fn values_are_flattened_to_one_line() {
        assert_eq!(one_line("a\nb\rc"), "a b c");
    }
}
