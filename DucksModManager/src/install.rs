//! Putting mods into the mods folder, and keeping local edits.
//!
//! Two rules shape everything here:
//!
//! * A mod is only ever updated from the pack, never guessed at. If the pack and the player both
//!   changed the same file and the two changes cannot be merged cleanly, the file is left exactly
//!   as it is and reported. Nothing is overwritten "just in case".
//! * Merging needs to know what the player started from, so every install records the pack commit
//!   it came from (`installed.conf`). Without that record there is no way to tell "the player
//!   edited this" from "the pack changed this".

use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::io;
use std::path::Path;

use crate::pack::{self, Tree};
use crate::saver;

/// The record of which pack version each installed mod came from, kept in the manager's appdata.
pub const RECORDS_FILE: &str = "installed.conf";

/// Where the pack's version of each installed mod is kept: the base a later merge works from.
pub const BASE_DIR: &str = "base";

/// What the list shows for one mod.
#[derive(Clone, Copy, PartialEq, Eq)]
pub enum State {
    NotInstalled,
    UpToDate,
    /// The pack moved on since this was installed.
    UpdateAvailable { changed: usize },
    /// The installed files no longer match the pack, and this is not simply an update.
    ModifiedLocally { changed: usize },
}

/// The changes that would bring one installed mod up to date.
#[derive(Default, Debug, PartialEq)]
pub struct Plan {
    /// Files to write into the install folder.
    pub writes: Vec<(String, Vec<u8>)>,
    /// Files to delete from the install folder.
    pub deletes: Vec<String>,
    /// Files left alone because both sides changed them.
    pub conflicts: Vec<String>,
}

/// What one mod's update actually did.
#[derive(Default, Debug, PartialEq)]
pub struct Report {
    pub written: usize,
    pub deleted: usize,
    /// Files left exactly as they were, because the pack and the player both changed them.
    pub conflicts: Vec<String>,
}

impl Report {
    /// True when nothing about the mod changed on disk.
    pub fn quiet(&self) -> bool {
        self.written == 0 && self.deleted == 0 && self.conflicts.is_empty()
    }
}

/// What the list should show for a mod, without changing anything. `record` is the fingerprint of
/// the pack version this mod was installed from, and `current` the fingerprint of the pack's
/// version of it now.
pub fn state(target: &Path, record: Option<&str>, current: &str, theirs: &Tree) -> State {
    if !target.is_dir() {
        return State::NotInstalled;
    }

    let ours = pack::read_tree(target);
    let changed = differences(&ours, theirs);
    if changed == 0 {
        return State::UpToDate;
    }

    // Installed from the version the pack is on, so the difference is the player's. Otherwise the
    // pack has moved on, and the cautious reading is that there is an update to take — the
    // savestate taken before writing is what makes that safe.
    match record {
        Some(record) if record == current => State::ModifiedLocally { changed },
        _ => State::UpdateAvailable { changed },
    }
}

/// How many files differ between an installed mod and the pack's copy of it.
pub fn differences(ours: &Tree, theirs: &Tree) -> usize {
    paths(ours, theirs)
        .into_iter()
        .filter(|path| ours.get(*path) != theirs.get(*path))
        .count()
}

/// Every path either side mentions, in a stable order.
fn paths<'a>(ours: &'a Tree, theirs: &'a Tree) -> BTreeSet<&'a str> {
    ours.keys()
        .chain(theirs.keys())
        .map(String::as_str)
        .collect()
}

/// Works out how to bring an installed mod up to date.
///
/// A pull makes the install mirror the pack: every file the pack still has is merged, so the player's
/// edits survive, and every file it does not have is removed — leftovers from an older layout
/// included, which is why a pull is what clears those up. The one exception is a file the base knew
/// about that the player then edited: removing that would throw their work away, so it is reported
/// instead.
///
/// With no `base` there is nothing to compare against, so the pack wins outright. The savestate taken
/// beforehand is what makes that acceptable.
pub fn plan(base: Option<&Tree>, ours: &Tree, theirs: &Tree) -> Plan {
    let Some(base) = base else {
        let mut plan = Plan::default();
        for (path, content) in theirs {
            if ours.get(path) != Some(content) {
                plan.writes.push((path.clone(), content.clone()));
            }
        }
        // Nothing here can tell the pack's files from left-behind ones, so anything the pack does not
        // have goes. That is what clears the remains of an older layout.
        for path in ours.keys() {
            if !theirs.contains_key(path) {
                plan.deletes.push(path.clone());
            }
        }
        return plan;
    };

    let all: BTreeSet<&str> = base
        .keys()
        .chain(ours.keys())
        .chain(theirs.keys())
        .map(String::as_str)
        .collect();

    let mut plan = Plan::default();

    for path in all {
        let base = base.get(path);
        let ours = ours.get(path);
        let theirs = theirs.get(path);

        match (ours != base, theirs != base) {
            // Nobody changed it, or both sides ended up with the same content.
            (false, false) => {}
            // Only the player changed it: their version stays — unless the pack has no such file at
            // all, because then it was added to the install folder after the fact rather than
            // edited, and a pull mirrors the pack.
            (true, false) => {
                if theirs.is_none() {
                    plan.deletes.push(path.to_owned());
                }
            }
            // Only the pack changed it: take the pack's version, or drop it if the pack dropped it.
            (false, true) => match theirs {
                Some(content) => plan.writes.push((path.to_owned(), content.clone())),
                None => plan.deletes.push(path.to_owned()),
            },
            // Both changed it, so only a genuine three-way merge of that file can decide.
            (true, true) => match (base, ours, theirs) {
                (Some(_), Some(ours), Some(theirs)) if ours == theirs => {}
                (Some(base), Some(ours), Some(theirs)) => {
                    match merge_bytes(path, base, ours, theirs) {
                        Some(content) => plan.writes.push((path.to_owned(), content)),
                        None => plan.conflicts.push(path.to_owned()),
                    }
                }
                // The pack dropped a file the player had edited: their work is not thrown away, it
                // is reported. Also covers files added on both sides, and one side deleting what
                // the other changed — not something to guess at.
                _ => plan.conflicts.push(path.to_owned()),
            },
        }
    }

    plan
}

/// `git2::merge_file` is the one entry point that does not initialise libgit2 on the way in, and
/// the first libgit2 call in a process fails without that. Left alone, that turns a perfectly
/// mergeable file into a "conflict" — silently, and only for whichever file happens to be merged
/// first. Touching an API that does initialise it, once, rules that out.
fn libgit2_ready() {
    static ONCE: std::sync::Once = std::sync::Once::new();
    ONCE.call_once(|| {
        let _ = git2::Signature::now("Ducks Mod Manager", "ducks@example.invalid");
    });
}

/// Three-way merges one file with libgit2. `None` means the two sides disagree in a way that cannot
/// be merged cleanly, so the caller leaves the file exactly as it is.
fn merge_bytes(path: &str, base: &[u8], ours: &[u8], theirs: &[u8]) -> Option<Vec<u8>> {
    libgit2_ready();

    // libgit2 reads a zero mode as "this side does not exist" (`GIT_MERGE_FILE_SIDE_EXISTS`), so
    // every side being merged has to say it is an ordinary file, even though all three are only
    // ever called with real content.
    let mode = Some(git2::FileMode::Blob);

    let mut ancestor = git2::MergeFileInput::new();
    ancestor.content(base);
    ancestor.path(path);
    ancestor.mode(mode);

    let mut ours_input = git2::MergeFileInput::new();
    ours_input.content(ours);
    ours_input.path(path);
    ours_input.mode(mode);

    let mut theirs_input = git2::MergeFileInput::new();
    theirs_input.content(theirs);
    theirs_input.path(path);
    theirs_input.mode(mode);

    // A null options pointer makes libgit2 fail outright, so the defaults are passed explicitly.
    let mut options = git2::MergeFileOptions::new();
    let merged = git2::merge_file(&ancestor, &ours_input, &theirs_input, Some(&mut options)).ok()?;

    // `is_automergeable` is false when the output is full of conflict markers, which is exactly
    // when nothing must be written.
    if merged.is_automergeable() {
        Some(merged.content().to_vec())
    } else {
        None
    }
}

/// Brings one mod up to date: writes `theirs` into `target`, merging around whatever the player
/// changed.
///
/// `base` is the pack's version of that mod from when it was installed, which is what makes a merge
/// possible at all. Without it there is nothing to compare against, so the pack simply wins — the
/// savestate taken beforehand is what covers that.
pub fn update(base: Option<&Tree>, theirs: &Tree, target: &Path) -> Result<Report, String> {
    let ours = pack::read_tree(target);

    // A mod that is not on disk at all is being *installed*, not merged: take the pack's version
    // wholesale. The base only means anything when there is something to merge into — otherwise
    // "the files are missing" reads as "the player deleted them" and the install quietly does
    // nothing, which is exactly what an "already up to date" on a missing mod looks like.
    let base = if ours.is_empty() { None } else { base };

    let plan = plan(base, &ours, theirs);
    apply(&plan, target).map_err(|err| err.to_string())?;

    Ok(Report {
        written: plan.writes.len(),
        deleted: plan.deletes.len(),
        conflicts: plan.conflicts,
    })
}

/// Writes a plan into the install folder.
pub fn apply(plan: &Plan, target: &Path) -> io::Result<()> {
    for (path, content) in &plan.writes {
        let file = target.join(path);
        if let Some(parent) = file.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(file, content)?;
    }

    for path in &plan.deletes {
        let file = target.join(path);
        if file.is_file() {
            fs::remove_file(&file)?;
        }
    }

    if !plan.deletes.is_empty() {
        prune_empty(target);
    }

    Ok(())
}

/// Drops folders left empty by deleted files, so an install never collects empty husks. The mod
/// folder itself is kept: the row is still an installed mod.
fn prune_empty(dir: &Path) {
    let Ok(entries) = fs::read_dir(dir) else {
        return;
    };

    for entry in entries.flatten() {
        if entry.file_type().is_ok_and(|kind| kind.is_dir()) {
            let path = entry.path();
            prune_empty(&path);
            // `remove_dir` only succeeds on an empty folder, which is exactly the test wanted.
            fs::remove_dir(&path).ok();
        }
    }
}

/// Reads the install record: mod path → the pack commit it was copied from.
pub fn read_records(path: &Path) -> BTreeMap<String, String> {
    let mut records = BTreeMap::new();
    let Ok(text) = fs::read_to_string(path) else {
        return records;
    };

    for line in text.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let Some((key, value)) = line.split_once('=') else {
            continue;
        };
        records.insert(key.trim().to_owned(), value.trim().to_owned());
    }

    records
}

/// Writes the install record, creating the manager's appdata folder if it is missing.
pub fn write_records(path: &Path, records: &BTreeMap<String, String>) -> io::Result<()> {
    let mut text =
        String::from("# Ducks Mod Manager: the pack commit each installed mod came from.\n");

    for (mod_path, commit) in records {
        text.push_str(&format!(
            "{} = {}\n",
            saver::one_line(mod_path),
            saver::one_line(commit)
        ));
    }

    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(path, text)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    fn tree(files: &[(&str, &str)]) -> Tree {
        files
            .iter()
            .map(|(path, content)| ((*path).to_owned(), content.as_bytes().to_vec()))
            .collect()
    }

    /// The writes in a plan, as text, so the tests read like the files they describe.
    fn written(plan: &Plan) -> Vec<(String, String)> {
        plan.writes
            .iter()
            .map(|(path, content)| (path.clone(), String::from_utf8_lossy(content).into_owned()))
            .collect()
    }

    /// Untouched files are not in the plan at all, and a file the player edited is left to the merge
    /// rather than written over.
    #[test]
    fn untouched_and_player_edited_files_are_left_alone() {
        let base = tree(&[("a.lua", "a"), ("b.lua", "b")]);
        let ours = tree(&[("a.lua", "a"), ("b.lua", "player")]);
        let theirs = tree(&[("a.lua", "a"), ("b.lua", "b")]);

        assert_eq!(plan(Some(&base), &ours, &theirs), Plan::default());
    }

    /// Files only the pack changed are taken, including ones the pack added.
    #[test]
    fn pack_only_changes_are_taken() {
        let base = tree(&[("a.lua", "old")]);
        let ours = tree(&[("a.lua", "old")]);
        let theirs = tree(&[("a.lua", "new"), ("added.lua", "new file")]);

        let plan = plan(Some(&base), &ours, &theirs);

        assert_eq!(
            written(&plan),
            vec![
                ("a.lua".to_owned(), "new".to_owned()),
                ("added.lua".to_owned(), "new file".to_owned()),
            ]
        );
        assert!(plan.deletes.is_empty());
        assert!(plan.conflicts.is_empty());
    }

    /// Both sides edited different parts of one file: libgit2 merges them, exactly as `git
    /// merge-file` does. These values are the ones git itself produces.
    #[test]
    fn non_overlapping_edits_are_merged() {
        let base = tree(&[("script.lua", "one\ntwo\nthree\nfour\nfive\n")]);
        let ours = tree(&[("script.lua", "one\nTWO\nthree\nfour\nfive\n")]);
        let theirs = tree(&[("script.lua", "one\ntwo\nthree\nfour\nFIVE\n")]);

        let plan = plan(Some(&base), &ours, &theirs);

        assert_eq!(
            written(&plan),
            vec![(
                "script.lua".to_owned(),
                "one\nTWO\nthree\nfour\nFIVE\n".to_owned()
            )]
        );
        assert!(plan.conflicts.is_empty());
    }

    /// Both sides edited the same lines: nothing is written, the file is reported instead. This is
    /// git's own rule, so edits on *adjacent* lines land here too — they are one hunk, not two.
    #[test]
    fn overlapping_edits_are_reported_not_guessed() {
        let base = tree(&[("script.lua", "one\ntwo\nthree\n")]);
        let ours = tree(&[("script.lua", "one\nPLAYER\nthree\n")]);
        let theirs = tree(&[("script.lua", "one\nPACK\nthree\n")]);

        let plan = plan(Some(&base), &ours, &theirs);

        assert!(plan.writes.is_empty());
        assert_eq!(plan.conflicts, vec!["script.lua".to_owned()]);
    }

    /// A file the pack dropped, that the player never touched, goes.
    #[test]
    fn files_the_pack_dropped_are_deleted() {
        let base = tree(&[("gone.lua", "x"), ("kept.lua", "x")]);
        let ours = tree(&[("gone.lua", "x"), ("kept.lua", "x")]);
        let theirs = tree(&[("kept.lua", "x")]);

        let plan = plan(Some(&base), &ours, &theirs);

        assert_eq!(plan.deletes, vec!["gone.lua".to_owned()]);
    }

    /// The pack dropped a file the player had edited: a disagreement, not a delete.
    #[test]
    fn a_deleted_but_edited_file_is_a_conflict() {
        let base = tree(&[("gone.lua", "x")]);
        let ours = tree(&[("gone.lua", "edited")]);
        let theirs = tree(&[]);

        let plan = plan(Some(&base), &ours, &theirs);

        assert_eq!(plan.conflicts, vec!["gone.lua".to_owned()]);
        assert!(plan.writes.is_empty());
        assert!(plan.deletes.is_empty());
    }

    /// The player deleted a file the pack changed: left alone as well.
    #[test]
    fn a_deleted_but_changed_file_is_a_conflict() {
        let base = tree(&[("f.lua", "x")]);
        let ours = tree(&[]);
        let theirs = tree(&[("f.lua", "new")]);

        let plan = plan(Some(&base), &ours, &theirs);

        assert_eq!(plan.conflicts, vec!["f.lua".to_owned()]);
    }

    /// The same file added on both sides has no base to merge against, so it is a conflict.
    #[test]
    fn files_added_on_both_sides_are_a_conflict() {
        let base = tree(&[]);
        let ours = tree(&[("new.lua", "player")]);
        let theirs = tree(&[("new.lua", "pack")]);

        let plan = plan(Some(&base), &ours, &theirs);

        assert_eq!(plan.conflicts, vec!["new.lua".to_owned()]);
    }

    /// With no record there is no base, so the pack wins outright: everything it has is written, and
    /// anything the install folder holds that it does not have is removed.
    #[test]
    fn without_a_base_the_pack_wins_outright() {
        let ours = tree(&[("a.lua", "old"), ("mine.lua", "player")]);
        let theirs = tree(&[("a.lua", "new"), ("b.lua", "pack")]);

        let plan = plan(None, &ours, &theirs);

        assert_eq!(
            written(&plan),
            vec![
                ("a.lua".to_owned(), "new".to_owned()),
                ("b.lua".to_owned(), "pack".to_owned()),
            ]
        );
        assert_eq!(plan.deletes, vec!["mine.lua".to_owned()]);
    }

    /// A file added to the install folder after the mod was installed is not part of the pack, so a
    /// pull takes it out. That is what clears leftovers from an older layout, where a buggy build
    /// could write a mod a level too deep.
    #[test]
    fn files_the_pack_never_had_are_deleted() {
        let base = tree(&[("kept.lua", "x")]);
        let ours = tree(&[("kept.lua", "x"), ("Ducks Mods/leftover.lua", "old")]);
        let theirs = tree(&[("kept.lua", "x")]);

        let plan = plan(Some(&base), &ours, &theirs);

        assert_eq!(plan.deletes, vec!["Ducks Mods/leftover.lua".to_owned()]);
        assert!(plan.writes.is_empty());
    }

    #[test]
    fn differences_counts_every_changed_path() {
        let ours = tree(&[("a.lua", "x"), ("b.lua", "x")]);
        let theirs = tree(&[("a.lua", "x"), ("b.lua", "y"), ("c.lua", "z")]);

        assert_eq!(differences(&ours, &theirs), 2);
        assert_eq!(differences(&ours, &ours), 0);
    }

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

    #[test]
    fn apply_writes_deletes_and_prunes_empty_folders() {
        let root = temp_root("ducksmm_install_apply");
        let target = root.join("Ducks Mods").join("Local Mods").join("DucksUI");
        write_file(&target.join("old.lua"), "old");
        write_file(&target.join("Nested").join("gone.lua"), "gone");

        let plan = Plan {
            writes: vec![("new.lua".to_owned(), b"new".to_vec())],
            deletes: vec!["Nested/gone.lua".to_owned()],
            conflicts: Vec::new(),
        };
        apply(&plan, &target).expect("apply the plan");

        assert!(target.join("new.lua").is_file());
        assert!(target.join("old.lua").is_file());
        // The folder the deleted file lived in goes too, but the mod folder itself stays.
        assert!(!target.join("Nested").exists());
        assert!(target.is_dir());

        fs::remove_dir_all(&root).ok();
    }

    #[test]
    fn state_reads_the_install_against_the_pack() {
        let root = temp_root("ducksmm_install_state");
        let target = root.join("Ducks Mods").join("Local Mods").join("DucksUI");
        let theirs = tree(&[("a.lua", "x")]);

        // Nothing on disk yet.
        assert!(matches!(
            state(&target, None, "head", &theirs),
            State::NotInstalled
        ));

        write_file(&target.join("a.lua"), "x");
        assert!(matches!(
            state(&target, Some("head"), "head", &theirs),
            State::UpToDate
        ));

        // Same commit as the pack is on, but the file differs: the player's edit.
        write_file(&target.join("a.lua"), "edited");
        assert!(matches!(
            state(&target, Some("head"), "head", &theirs),
            State::ModifiedLocally { changed: 1 }
        ));

        // Installed from an older commit: an update to take.
        assert!(matches!(
            state(&target, Some("older"), "head", &theirs),
            State::UpdateAvailable { changed: 1 }
        ));

        fs::remove_dir_all(&root).ok();
    }

    #[test]
    fn records_round_trip() {
        let root = temp_root("ducksmm_install_records");
        let path = root.join(RECORDS_FILE);

        let mut records = BTreeMap::new();
        records.insert("Local Mods/DucksUI".to_owned(), "def5678".to_owned());
        records.insert(
            "AddUtility(REQUIRED_FOR_MODS)/AddUtility".to_owned(),
            "abc1234".to_owned(),
        );

        write_records(&path, &records).expect("write the records");
        assert_eq!(read_records(&path), records);

        fs::remove_dir_all(&root).ok();
    }

    /// A mod whose folder is gone is being installed, not merged. The base still remembers those
    /// files, and reading that as "the player deleted them" is what made Install report a missing
    /// mod as "already up to date".
    #[test]
    fn a_missing_install_is_installed_not_merged() {
        let root = temp_root("ducksmm_install_missing");
        let target = root.join("Ducks Mods").join("Local Mods").join("DucksUI");
        let base = tree(&[("script.lua", "-- one")]);
        let theirs = tree(&[("script.lua", "-- one")]);

        let report = update(Some(&base), &theirs, &target).expect("install");

        assert_eq!(report.written, 1);
        assert_eq!(
            fs::read_to_string(target.join("script.lua")).unwrap(),
            "-- one"
        );

        fs::remove_dir_all(&root).ok();
    }
}
