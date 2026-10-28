//! Prototype GUI for the Ducks mod manager: layout and interaction only.
//!
//! The only files it touches are its own, all beside the mods folder: `settings.conf`, the pack copy
//! under `pack`, the merge bases under `base`, the install record, and the savestates. The one thing
//! that cannot live there is a one-line pointer to that folder, kept next to the executable.
//!
//! Nothing here shells out to git. The pack is a plain HTTPS download of GitHub's archive, so this
//! works on a machine that has never had git installed. The loader registers new `.lua` files by
//! itself, so installing a mod is all that is needed for it to show up in game.

use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};

use eframe::egui::{self, Align, Color32, Layout, RichText};

use crate::install;
use crate::pack::{self, Tree};
use crate::saver;

const REPO_URL: &str = "https://github.com/SavageDuck26/Ducks-Gauntlet-Mods.git";
const DEFAULT_BRANCH: &str = "main";
const DEFAULT_INSTALL_NAME: &str = "Ducks Mods";

/// The manager's own folder. It sits one level above the mod install — beside the mods folder
/// rather than inside it — so the game's loader never scans it.
const APPDATA_DIR: &str = "DucksModManager";
const SETTINGS_FILE: &str = "settings.conf";

/// One line beside the executable holding the mods folder picked last time. It has to live outside
/// the mods tree: it is the only thing that can lead the manager back to its appdata folder.
///
/// The name carries the platform because the folder it points at is written the way that platform
/// writes paths. Ship both builds in one folder — as `dist/` does — and a shared name would have
/// them overwriting each other, leaving whichever launched second pointed at a path the other OS
/// cannot read.
const POINTER_FILE: &str = if cfg!(windows) {
    "DucksModManager-windows.path"
} else {
    "DucksModManager.path"
};

const ROW_HEIGHT: f32 = 22.0;
const COL_CHECK: f32 = 20.0;
const COL_NAME: f32 = 200.0;
const COL_CATEGORY: f32 = 150.0;
const COL_STATUS: f32 = 118.0;
const COL_CHANGED: f32 = 62.0;
const COL_ACTIONS: f32 = 112.0;
/// Must match `Ui::spacing().item_spacing.x` so the plain header row lines up with the grid rows.
const COL_SPACING: f32 = 6.0;

/// The header's 2x2 button block. Fixed sizes keep the two columns lined up.
const BUTTON_WIDE: f32 = 120.0;
const BUTTON_NARROW: f32 = 84.0;
const BUTTON_HEIGHT: f32 = 22.0;
/// Wide enough for a savestate's name in the restore dropdown.
const PICK_WIDTH: f32 = 150.0;

/// The panel on the right, where the pack's own documentation is shown. Wide enough for the prose
/// to be readable, and narrow enough that the mod list's columns still fit beside it at the default
/// window size. Draggable either way.
const DOCS_WIDTH: f32 = 400.0;

/// Shared status colours, so the update badge and the list pills can never drift apart.
const OK_COLOR: Color32 = Color32::from_rgb(96, 190, 116);
const WARN_COLOR: Color32 = Color32::from_rgb(226, 178, 84);
const ERROR_COLOR: Color32 = Color32::from_rgb(226, 118, 118);
const EDIT_COLOR: Color32 = Color32::from_rgb(120, 164, 226);

/// What the list row needs to know about a mod's install state.
#[derive(Clone, Copy, PartialEq, Eq)]
enum Status {
    NotInstalled,
    UpToDate,
    UpdateAvailable,
    /// The installed copy no longer matches the pack. It is not overwritten: the pack's changes
    /// get merged into it, and anything that conflicts is left exactly as it is.
    ModifiedLocally,
}

impl Status {
    fn label(self) -> &'static str {
        match self {
            Status::NotInstalled => "not installed",
            Status::UpToDate => "up to date",
            Status::UpdateAvailable => "update available",
            Status::ModifiedLocally => "local edits",
        }
    }

    fn color(self, dark: bool) -> Color32 {
        match self {
            Status::NotInstalled => Color32::from_gray(if dark { 140 } else { 110 }),
            Status::UpToDate => OK_COLOR,
            Status::UpdateAvailable => WARN_COLOR,
            Status::ModifiedLocally => EDIT_COLOR,
        }
    }

    /// `NotInstalled` is the only state where nothing of the mod is on disk yet. Pulls and the
    /// pre-pull backup only ever look at installed rows.
    fn is_installed(self) -> bool {
        !matches!(self, Status::NotInstalled)
    }
}

struct ModEntry {
    category: String,
    name: String,
    status: Status,
    changed_files: usize,
    selected: bool,
    required: bool,
}

/// The row's status, from what the engine found on disk.
fn status_of(state: install::State) -> (Status, usize) {
    match state {
        install::State::NotInstalled => (Status::NotInstalled, 0),
        install::State::UpToDate => (Status::UpToDate, 0),
        install::State::UpdateAvailable { changed } => (Status::UpdateAvailable, changed),
        install::State::ModifiedLocally { changed } => (Status::ModifiedLocally, changed),
    }
}

/// The pack says which mods it cannot run without in the folder name — `AddUtility(REQUIRED_FOR_MODS)`
/// — so reading it off the name is enough here.
fn is_required(category: &str) -> bool {
    category.to_ascii_uppercase().contains("REQUIRED")
}

/// A mod's path inside the pack and inside the install.
///
/// The same rule as `PackMod::rel_path`: usually `<category>/<name>`, but a mod that *is* its own
/// top-level folder — `AddUtility(REQUIRED_FOR_MODS)`, `Trials Mods` — is that folder, not a folder
/// nested inside itself. Getting this wrong points installs, deletes and ticks at a path that does
/// not exist.
fn rel_path(entry: &ModEntry) -> String {
    if entry.category == entry.name {
        entry.category.clone()
    } else {
        format!("{}/{}", entry.category, entry.name)
    }
}

/// User choices. `mods_root` is always picked at runtime — no path is compiled in.
///
/// Every frame this is compared against the copy last written to disk, so autosave only touches the
/// file when something really changed.
#[derive(Clone, PartialEq)]
struct Settings {
    repo_url: String,
    branch: String,
    mods_root: Option<PathBuf>,
    install_name: String,
    savestate_before_pull: bool,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            repo_url: REPO_URL.to_owned(),
            branch: DEFAULT_BRANCH.to_owned(),
            mods_root: None,
            install_name: DEFAULT_INSTALL_NAME.to_owned(),
            // A pull overwrites the installed mods wholesale, so snapshot them first.
            savestate_before_pull: true,
        }
    }
}

/// Result of the last check against the remote.
///
/// `Checking` is rendered by the header but nothing sets it yet: the check is synchronous, so it
/// never spends a frame in that state. `Failed` is real, and shown when a fetch cannot happen.
#[allow(dead_code)]
enum UpdateState {
    Unknown,
    Checking,
    UpToDate { version: String },
    Behind { count: usize },
    Failed(String),
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Level {
    Info,
    Warn,
}

struct LogLine {
    level: Level,
    text: String,
}

/// Everything the UI can ask for. Rows only read state and return an action, so no widget needs a
/// mutable borrow of the app while the layout is being built.
enum Action {
    Browse,
    OpenFolder,
    OpenRepo,
    OpenDocs,
    CheckUpdates,
    PullUpdate,
    InstallSelected,
    MakeSavestate,
    /// Rewrite the chosen savestate with the mods that are installed right now.
    OverwriteState,
    RestoreState,
    InstallRow(usize),
    /// A row's Delete button. A mod the pack needs only asks for confirmation here.
    DeleteRow(usize),
    /// Deleting a mod the pack needs, once the player has said yes.
    ForceDeleteRow(usize),
    SetRow(usize, bool),
    SelectAll,
    SelectNone,
    SelectNeedingAction,
    ClearLog,
}

pub struct ModManagerApp {
    settings: Settings,
    /// The settings as they exist on disk, so autosave can tell when there is something to write.
    saved: Settings,
    mods: Vec<ModEntry>,
    log: Vec<LogLine>,
    filter: String,
    only_needing_action: bool,
    update: UpdateState,
    /// What the player wants the next savestate called. Empty means "name it after the date".
    savestate_name: String,
    /// The savestates on disk, as of the last time we looked. Held here so the restore dropdown
    /// does not read the folder on every frame.
    savestates: Vec<saver::Savestate>,
    /// Which of them the dropdown has picked.
    restore_choice: String,
    /// The mod a delete is waiting on a yes/no for. Only a mod the pack needs ever asks, so this is
    /// `None` for every ordinary delete.
    confirm_delete: Option<usize>,
    /// The pack's own documentation, as of the last time the pack copy was read. Held here because
    /// the panel is drawn every frame and the file comes off disk.
    doc: Option<String>,
}

impl ModManagerApp {
    pub fn new(cc: &eframe::CreationContext<'_>) -> Self {
        // The whole interface is built for a dark background, so the theme is pinned rather than
        // followed. egui re-reads the OS theme every frame: left on "follow the system", a machine
        // set to light mode gets the light palette and every custom colour here stops working —
        // which is exactly what a stock Windows install did. The window frame is asked for the same
        // theme, so the title bar does not come back white on top of a dark window.
        cc.egui_ctx.set_theme(egui::ThemePreference::Dark);
        cc.egui_ctx.send_viewport_cmd(egui::ViewportCommand::SetTheme(egui::SystemTheme::Dark));
        cc.egui_ctx.set_visuals(egui::Visuals::dark());
        // Item spacing drives the header row, so it has to match the grid's column spacing.
        cc.egui_ctx.style_mut(|style| style.spacing.item_spacing = egui::vec2(COL_SPACING, 6.0));

        let mut app = Self {
            settings: Settings::default(),
            saved: Settings::default(),
            mods: Vec::new(),
            log: Vec::new(),
            filter: String::new(),
            only_needing_action: false,
            update: UpdateState::Unknown,
            savestate_name: String::new(),
            savestates: Vec::new(),
            restore_choice: String::new(),
            confirm_delete: None,
            doc: None,
        };
        app.info("Ducks Mod Manager 0.1.");
        app.info(format!("Pack: {REPO_URL} ({DEFAULT_BRANCH})"));
        app.info(format!(
            "Settings and savestates are kept in {APPDATA_DIR} beside the mods folder."
        ));

        // Pick up where the last run left off, then look for updates straight away.
        if app.restore_last_folder() {
            app.info("Auto-checking for updates on open.");
            app.check_updates();
        } else {
            app.info("Pick the folder where your mods live (Browse…) — no path is hardcoded.");
        }
        app
    }

    fn info(&mut self, text: impl Into<String>) {
        self.log.push(LogLine { level: Level::Info, text: text.into() });
    }

    fn warn(&mut self, text: impl Into<String>) {
        self.log.push(LogLine { level: Level::Warn, text: text.into() });
    }

    /// Where the manager writes: `<mods_root>/<install_name>`.
    fn destination(&self) -> Option<PathBuf> {
        let name = self.settings.install_name.trim();
        self.settings
            .mods_root
            .as_ref()
            .map(|root| if name.is_empty() { root.clone() } else { root.join(name) })
    }

    /// The manager's own copy of the pack, inside its appdata folder.
    fn pack_dir(&self) -> Option<PathBuf> {
        Some(self.appdata_dir()?.join(pack::PACK_DIR))
    }

    /// Where the record of what each installed mod came from lives.
    fn records_path(&self) -> Option<PathBuf> {
        Some(self.appdata_dir()?.join(install::RECORDS_FILE))
    }

    /// The install record: mod path → the pack commit it was copied from.
    fn records(&self) -> BTreeMap<String, String> {
        match self.records_path() {
            Some(path) => install::read_records(&path),
            None => BTreeMap::new(),
        }
    }

    /// Where the pack's version of each installed mod is kept: the base a later merge works from.
    fn base_dir(&self) -> Option<PathBuf> {
        Some(self.appdata_dir()?.join(install::BASE_DIR))
    }

    /// Remembers the pack's version of a mod as the base for the next merge.
    ///
    /// Deliberately the pack's copy and not what ended up on disk: if a file conflicted, storing the
    /// player's version would make the next pull think nothing had changed locally and overwrite the
    /// very edit we just protected.
    fn save_base(&mut self, theirs: &Tree, rel: &str) {
        let Some(base_dir) = self.base_dir() else {
            return;
        };
        let root = base_dir.join(rel);
        fs::remove_dir_all(&root).ok();

        for (path, content) in theirs {
            let file = root.join(path);
            if let Some(parent) = file.parent() {
                fs::create_dir_all(parent).ok();
            }
            if let Err(err) = fs::write(&file, content) {
                self.warn(format!("Could not keep a merge base for {rel}: {err}"));
                return;
            }
        }
    }

    /// Rebuilds the list from the pack: which mods it has, what is installed, and how they differ.
    fn refresh_mods(&mut self, pack_dir: &Path) {
        let records = self.records();
        let install_dir = self.destination();

        // Whatever the player had ticked stays ticked, for mods that were already listed.
        let ticked: BTreeMap<String, bool> = self
            .mods
            .iter()
            .map(|entry| (rel_path(entry), entry.selected))
            .collect();

        let mut mods = Vec::new();
        for pack_mod in pack::mods(pack_dir) {
            let rel = pack_mod.rel_path();
            let theirs = pack::read_tree(&pack::locate(pack_dir, &rel));
            let current = pack::fingerprint(&theirs);

            let state = match install_dir.as_ref().map(|dir| dir.join(&rel)) {
                Some(target) => install::state(
                    &target,
                    records.get(&rel).map(String::as_str),
                    &current,
                    &theirs,
                ),
                None => install::State::NotInstalled,
            };
            let (status, changed_files) = status_of(state);
            let required = is_required(&pack_mod.category);

            mods.push(ModEntry {
                category: pack_mod.category,
                name: pack_mod.name,
                status,
                changed_files,
                // Nothing that is not already installed starts ticked: an update only refreshes what
                // is there, so installing a new mod stays an explicit choice.
                selected: ticked
                    .get(&rel)
                    .copied()
                    .unwrap_or(required || status == Status::UpdateAvailable),
                required,
            });
        }

        self.mods = mods;
    }

    /// Remembers which pack commit the given mods were just taken from.
    fn record_installed(&mut self, rel: &str, fingerprint: &str) {
        let Some(path) = self.records_path() else {
            return;
        };

        let mut records = install::read_records(&path);
        records.insert(rel.to_owned(), fingerprint.to_owned());

        if let Err(err) = install::write_records(&path, &records) {
            self.warn(format!("Could not record what was installed: {err}"));
        }
    }

    /// Drops the install record for mods that are no longer on disk.
    fn forget_installed(&mut self, mods: &[String]) {
        let Some(path) = self.records_path() else {
            return;
        };

        let mut records = install::read_records(&path);
        for rel in mods {
            records.remove(rel);
        }

        if let Err(err) = install::write_records(&path, &records) {
            self.warn(format!("Could not update the install record: {err}"));
        }
    }

    /// Brings one mod up to date from the pack, merging around local edits, then records where it
    /// came from. Problems are logged here.
    fn update_one(&mut self, pack_dir: &Path, install_dir: &Path, rel: &str) {
        let theirs = pack::read_tree(&pack::locate(pack_dir, rel));

        // Nothing in the pack at this path means the row is stale or the pack copy is older than the
        // list — say that, rather than reporting a mod as "already up to date" when there is
        // nothing to install from.
        if theirs.is_empty() {
            self.warn(format!(
                "{rel}: the pack copy has nothing at that path — run Check for updates."
            ));
            return;
        }

        // The base is the pack's version of this mod from last time, which is what the player
        // started from. A mod that has never been installed has no base, and the pack wins.
        let base = self
            .base_dir()
            .map(|dir| pack::read_tree(&dir.join(rel)))
            .filter(|tree| !tree.is_empty());

        match install::update(base.as_ref(), &theirs, &install_dir.join(rel)) {
            Ok(report) => {
                self.report_update(rel, &report);
                self.save_base(&theirs, rel);
                self.record_installed(rel, &pack::fingerprint(&theirs));
            }
            Err(err) => self.warn(format!("{rel}: could not update: {err}")),
        }
    }

    /// Warns once about installed mods that predate the install record. With nothing on record
    /// there is no base to merge against, so the pack's version wins for those — the savestate is
    /// what covers it, and every update from here on records its base.
    fn warn_about_unrecorded(&mut self, mods: &[String]) {
        let records = self.records();
        let unrecorded = mods.iter().filter(|rel| !records.contains_key(*rel)).count();

        if unrecorded > 0 {
            self.warn(format!(
                "{unrecorded} installed mod(s) have no record of where they came from, so the \
                 pack's version wins for them. Updates from now on merge properly."
            ));
        }
    }

    /// Says what an update did, in the log.
    fn report_update(&mut self, rel: &str, report: &install::Report) {
        if report.quiet() {
            self.info(format!("{rel}: already up to date."));
        } else if report.conflicts.is_empty() {
            self.info(format!(
                "{rel}: {} file(s) written, {} removed.",
                report.written, report.deleted
            ));
        } else {
            self.warn(format!(
                "{rel}: {} file(s) written, {} left alone — the pack and your edits both changed \
                 them: {}",
                report.written,
                report.conflicts.len(),
                report.conflicts.join(", ")
            ));
        }
    }

    fn handle(&mut self, action: Action) {
        match action {
            Action::Browse => self.browse(),
            Action::OpenFolder => self.open_destination(),
            Action::OpenRepo => {
                if let Err(err) = open_url(&self.settings.repo_url) {
                    self.warn(format!("Could not open the browser: {err}"));
                }
            }
            Action::OpenDocs => self.open_docs(),
            Action::CheckUpdates => self.check_updates(),
            Action::PullUpdate => self.pull_update(),
            Action::InstallSelected => self.install_selected(),
            Action::MakeSavestate => self.make_savestate(),
            Action::OverwriteState => self.overwrite_savestate(),
            Action::RestoreState => self.restore_savestate(),
            Action::InstallRow(index) => self.install_one(index),
            Action::DeleteRow(index) => self.ask_to_delete(index),
            Action::ForceDeleteRow(index) => self.delete_one(index),
            Action::SetRow(index, selected) => {
                if let Some(entry) = self.mods.get_mut(index) {
                    // AddUtility is mandatory: the pack does not run without it.
                    if !entry.required {
                        entry.selected = selected;
                    }
                }
            }
            Action::SelectAll => {
                for entry in &mut self.mods {
                    entry.selected = true;
                }
                self.info("Selected every mod.");
            }
            Action::SelectNone => {
                for entry in &mut self.mods {
                    if !entry.required {
                        entry.selected = false;
                    }
                }
                self.info("Cleared the selection; required mods stay selected.");
            }
            Action::SelectNeedingAction => {
                for entry in &mut self.mods {
                    entry.selected = entry.required || entry.status != Status::UpToDate;
                }
                self.info("Selected mods that are missing or out of date.");
            }
            Action::ClearLog => self.log.clear(),
        }
    }

    /// Native folder picker: real Explorer dialog on Windows, portal dialog on Linux.
    fn browse(&mut self) {
        let mut dialog = rfd::FileDialog::new().set_title("Select the folder where your mods go");
        // Only a folder that exists on *this* system is offered as a starting point. A path saved on
        // the other platform — a Linux mods folder under Wine, say — is not merely useless here:
        // Windows' folder dialog refuses to open at all, with "Invalid character(s) in path", rather
        // than falling back to somewhere sensible.
        if let Some(root) = self.settings.mods_root.as_ref().filter(|root| root.is_dir()) {
            dialog = dialog.set_directory(root);
        }

        match dialog.pick_folder() {
            Some(folder) => {
                self.info(format!("Mods folder set to {}", folder.display()));
                self.settings.mods_root = Some(folder);
                // Remember the choice, then read whatever settings already sit in that folder.
                self.save_pointer();
                self.load_settings();
            }
            None => self.info("Folder picker cancelled."),
        }
    }

    /// Pick up the mods folder chosen last time from the pointer beside the executable, then load
    /// the settings that live in it. Returns false when there is nothing usable to restore.
    fn restore_last_folder(&mut self) -> bool {
        let Some(path) = pointer_path() else {
            return false;
        };
        let Some(folder) = read_pointer(&path) else {
            return false;
        };

        if !folder.is_dir() {
            self.warn(format!(
                "Last mods folder {} is not there any more — pick it again.",
                folder.display()
            ));
            return false;
        }

        self.info(format!("Restored mods folder {}", folder.display()));
        self.settings.mods_root = Some(folder);
        self.load_settings();
        true
    }

    /// Record the mods folder beside the executable, so the next launch can find its appdata.
    fn save_pointer(&mut self) {
        let Some(path) = pointer_path() else {
            return;
        };
        let Some(folder) = self.settings.mods_root.as_ref() else {
            return;
        };

        if let Err(err) = write_pointer(&path, folder) {
            self.warn(format!(
                "Could not remember the mods folder in {}: {err}",
                path.display()
            ));
        }
    }

    /// `DucksModManager` beside the mods folder. Until a mods folder is picked there is nowhere to
    /// look, so the folder has to be chosen once per launch before saved settings can be found.
    fn appdata_dir(&self) -> Option<PathBuf> {
        Some(appdata_dir(self.settings.mods_root.as_ref()?))
    }

    /// The settings file, once a mods folder has been chosen.
    fn settings_path(&self) -> Option<PathBuf> {
        Some(self.appdata_dir()?.join(SETTINGS_FILE))
    }

    /// Read the settings file for the chosen folder. No file is normal: it just means the manager
    /// has not run against this folder before, so the defaults get written out instead.
    fn load_settings(&mut self) {
        let Some(path) = self.settings_path() else {
            return;
        };

        let mods_root = self.settings.mods_root.clone();
        match read_settings(&path) {
            Some(loaded) => {
                self.settings = loaded;
                // The file lives in this folder, so the folder itself is never stored inside it.
                self.settings.mods_root = mods_root;
                self.saved = self.settings.clone();
                self.info(format!("Loaded settings from {}", path.display()));
            }
            None => {
                self.info(format!(
                    "No settings at {} yet — writing the defaults there.",
                    path.display()
                ));
                self.save_settings();
            }
        }

        // The mods folder is what tells us where the savestates live, and where the pack copy —
        // and so the pack's own documentation — is.
        self.refresh_savestates();
        self.refresh_doc();
    }

    /// Reads the pack's own documentation into memory for the panel on the right.
    ///
    /// It comes off the pack copy on disk, so this is called whenever that copy changes rather than
    /// from the panel itself: the panel is redrawn every frame, and the file is not.
    fn refresh_doc(&mut self) {
        self.doc = self.pack_dir().and_then(|dir| pack::read_doc(&dir));
    }

    /// Re-reads the savestates and keeps the dropdown pointing at something that exists.
    fn refresh_savestates(&mut self) {
        let Some(root) = self.savestate_root() else {
            self.savestates.clear();
            self.restore_choice.clear();
            return;
        };

        self.savestates = saver::list(&root);
        if !self
            .savestates
            .iter()
            .any(|state| state.stamp == self.restore_choice)
        {
            self.restore_choice = self
                .savestates
                .first()
                .map(|state| state.stamp.clone())
                .unwrap_or_default();
        }
    }

    /// Write the settings file, creating the `DucksModManager` folder if it does not exist yet.
    fn save_settings(&mut self) {
        let Some(path) = self.settings_path() else {
            // Nowhere to write yet: the choice stays in memory until a mods folder is picked.
            return;
        };

        match write_settings(&path, &self.settings) {
            Ok(()) => self.saved = self.settings.clone(),
            Err(err) => {
                self.warn(format!("Could not save settings to {}: {err}", path.display()));
                // Treat the failure as handled so the warning is not repeated every frame.
                self.saved = self.settings.clone();
            }
        }
    }

    fn open_destination(&mut self) {
        let Some(destination) = self.destination() else {
            self.warn("Pick the mods folder first.");
            return;
        };
        if !destination.exists() {
            self.warn(format!(
                "{} does not exist yet — install something first.",
                destination.display()
            ));
            return;
        }
        if let Err(err) = open_path(&destination) {
            self.warn(format!("Could not open {}: {err}", destination.display()));
        }
    }

    /// Where the pack keeps its documentation, once a pack copy is on disk.
    fn doc_path(&self) -> Option<PathBuf> {
        Some(pack::doc_path(&self.pack_dir()?))
    }

    /// Opens the folder the pack keeps its documentation in, so the other `.md` files beside the
    /// one on screen are a click away.
    fn open_docs(&mut self) {
        let Some(dir) = self
            .doc_path()
            .and_then(|path| path.parent().map(Path::to_path_buf))
        else {
            self.warn("Pick the mods folder first.");
            return;
        };

        if let Err(err) = open_path(&dir) {
            self.warn(format!("Could not open {}: {err}", dir.display()));
        }
    }

    /// Downloads the pack if it has changed, then works out what that means for the installed mods.
    /// The fetch is a plain HTTPS download of GitHub's archive — no git, no API, no token.
    fn check_updates(&mut self) {
        let Some(pack_dir) = self.pack_dir() else {
            self.warn("Pick the mods folder first.");
            return;
        };

        let url = pack::archive_url(&self.settings.repo_url, &self.settings.branch);
        match pack::refresh(&pack_dir, &url) {
            Ok(pack::Refreshed::Unchanged { version }) => {
                self.info(format!("Pack is up to date ({version})."));
            }
            Ok(pack::Refreshed::Changed { version }) => {
                self.info(format!("Pack updated to {version}."));
            }
            Err(err) => {
                self.warn(format!("Could not fetch the pack: {err}"));
                self.update = UpdateState::Failed(err);
                return;
            }
        }

        // Rebuild the list, so the statuses reflect the pack that was just fetched. The pack's docs
        // came down with it, so the panel on the right is re-read too.
        self.refresh_mods(&pack_dir);
        self.refresh_doc();
        self.settle_update_state(&pack_dir);
    }

    /// Sets the header state from what the list now says: how many installed mods the pack has moved
    /// on for.
    fn settle_update_state(&mut self, pack_dir: &Path) {
        let waiting = self
            .mods
            .iter()
            .filter(|entry| entry.status == Status::UpdateAvailable)
            .count();

        self.update = if waiting > 0 {
            self.info(format!("{waiting} installed mod(s) have updates."));
            UpdateState::Behind { count: waiting }
        } else {
            UpdateState::UpToDate {
                version: pack::version_of(pack_dir).unwrap_or_default(),
            }
        };
    }

    /// What a pull does, in order: snapshot the installed mods, fast-forward the checkout, then
    /// refresh only the mods that are actually installed.
    fn pull_update(&mut self) {
        let (Some(pack_dir), Some(destination)) = (self.pack_dir(), self.destination()) else {
            self.warn("Pick the mods folder first.");
            return;
        };

        // 1. Snapshot what is on disk before touching it, so a bad pull can always be undone.
        if self.settings.savestate_before_pull {
            self.take_savestate(&destination, "before pulling an update", "");
        } else {
            self.info("Savestating before a pull is switched off in Advanced.");
        }

        // 2. Make sure the pack copy is current. This is the same download as Check for updates, so
        //    the button works on its own without pressing that first.
        let url = pack::archive_url(&self.settings.repo_url, &self.settings.branch);
        match pack::refresh(&pack_dir, &url) {
            Ok(pack::Refreshed::Unchanged { version }) => {
                self.info(format!("Pack is already up to date ({version})."));
            }
            Ok(pack::Refreshed::Changed { version }) => {
                self.info(format!("Pack updated to {version}."));
            }
            Err(err) => {
                self.warn(format!("Could not fetch the pack: {err}"));
                self.update = UpdateState::Failed(err);
                return;
            }
        }

        // The list has to be rebuilt against the pack that was just fetched before anything is
        // written to the mods folder. The docs came down with the pack, so they are re-read here as
        // well — a pull on its own can be the first fetch after an update.
        self.refresh_mods(&pack_dir);
        self.refresh_doc();

        // 3. Bring the installed mods along. Only the ones already installed: a pull refreshes what
        //    is there, and installing something new stays an explicit choice.
        let installed: Vec<String> = self
            .mods
            .iter()
            .filter(|entry| entry.status.is_installed())
            .map(rel_path)
            .collect();
        let missing = self.mods.len() - installed.len();

        self.warn_about_unrecorded(&installed);
        for rel in &installed {
            self.update_one(&pack_dir, &destination, rel);
        }

        self.refresh_mods(&pack_dir);
        self.settle_update_state(&pack_dir);
        self.info(format!("{} installed mod(s) checked.", installed.len()));
        if missing > 0 {
            self.info(format!(
                "{missing} mod(s) are not installed and were left alone."
            ));
        }
    }

    /// Where the pre-pull archive goes: beside the mods folder, never inside it, so the loader
    /// never sees it. The Unix stamp keeps each pull's snapshot separate.
    fn savestate_root(&self) -> Option<PathBuf> {
        Some(self.appdata_dir()?.join(saver::SAVESTATE_DIR))
    }

    /// Snapshot the installed mods into `DucksModManager/savestate`, so a bad pull can be undone.
    /// A savestate is a plain copy — see [`crate::saver`] for why it is not git.
    fn take_savestate(&mut self, destination: &Path, label: &str, name: &str) {
        let Some(root) = self.savestate_root() else {
            self.warn("Pick the mods folder first.");
            return;
        };
        if !destination.is_dir() {
            self.info(format!(
                "Nothing to savestate yet: {} does not exist.",
                destination.display()
            ));
            return;
        }

        match saver::create(&root, destination, name, label) {
            Ok(stamp) => {
                self.info(format!("Savestate {stamp} taken {label}."));
                self.refresh_savestates();
            }
            Err(err) => self.warn(format!(
                "Could not write a savestate to {}: {err}",
                root.display()
            )),
        }
    }

    /// Take a savestate on request, from the header button, under the name in the box beside it.
    fn make_savestate(&mut self) {
        let Some(destination) = self.destination() else {
            self.warn("Pick the mods folder first.");
            return;
        };

        let name = self.savestate_name.trim().to_owned();
        self.take_savestate(&destination, "by hand", &name);
        self.savestate_name.clear();
    }

    /// Put a savestate back, from the header button.
    ///
    /// The dropdown picks which one. This replaces whatever is in the mods folder and is not itself
    /// undoable, so taking a savestate first is worth doing when in doubt.
    fn restore_savestate(&mut self) {
        let (Some(root), Some(destination)) = (self.savestate_root(), self.destination()) else {
            self.warn("Pick the mods folder first.");
            return;
        };

        let Some(stamp) = self.chosen_savestate() else {
            self.warn("There is no savestate to restore — take one first.");
            return;
        };

        match saver::restore(&root, &stamp, &destination) {
            Ok(()) => {
                self.info(format!("Restored savestate {stamp}."));
                if let Some(pack_dir) = self.pack_dir() {
                    self.refresh_mods(&pack_dir);
                }
            }
            Err(err) => self.warn(format!("Could not restore {stamp}: {err}")),
        }
    }

    /// Bring the chosen savestate up to date with the mods that are installed right now.
    ///
    /// The name in the dropdown says which savestate this is about, so it is rewritten in place
    /// rather than added as another one — that is the difference between this and *Make savestate*,
    /// which never overwrites anything. Nothing here can be undone: what the savestate held is gone
    /// once it returns, which is why the log says so out loud.
    fn overwrite_savestate(&mut self) {
        let (Some(root), Some(destination)) = (self.savestate_root(), self.destination()) else {
            self.warn("Pick the mods folder first.");
            return;
        };
        if !destination.is_dir() {
            self.warn(format!(
                "There is nothing to overwrite it with: {} does not exist yet.",
                destination.display()
            ));
            return;
        }

        let Some(stamp) = self.chosen_savestate() else {
            self.warn("There is no savestate to overwrite — take one first.");
            return;
        };

        match saver::overwrite(&root, &stamp, &destination, "overwritten by hand") {
            Ok(()) => {
                self.warn(format!(
                    "Savestate {stamp} was replaced with the installed mods. What it held before \
                     is gone."
                ));
                self.refresh_savestates();
            }
            Err(err) => self.warn(format!("Could not overwrite {stamp}: {err}")),
        }
    }

    /// The savestate the dropdown has picked, as long as it is still on disk.
    fn chosen_savestate(&self) -> Option<String> {
        self.savestates
            .iter()
            .find(|state| state.stamp == self.restore_choice)
            .map(|state| state.stamp.clone())
    }

    /// Installs the ticked mods from the pack.
    fn install_selected(&mut self) {
        let (Some(pack_dir), Some(destination)) = (self.pack_dir(), self.destination()) else {
            self.warn("Pick the mods folder first.");
            return;
        };

        let chosen: Vec<String> = self
            .mods
            .iter()
            .filter(|entry| entry.selected)
            .map(rel_path)
            .collect();

        if chosen.is_empty() {
            self.warn("Nothing selected.");
            return;
        }

        self.warn_about_unrecorded(&chosen);
        for rel in &chosen {
            self.update_one(&pack_dir, &destination, rel);
        }

        self.refresh_mods(&pack_dir);
        self.info(format!("{} mod(s) installed.", chosen.len()));
    }

    /// Install — or reinstall — one mod, straight from its row button.
    fn install_one(&mut self, index: usize) {
        let (Some(pack_dir), Some(destination)) = (self.pack_dir(), self.destination()) else {
            self.warn("Pick the mods folder first.");
            return;
        };

        let Some(entry) = self.mods.get(index) else {
            return;
        };
        let rel = rel_path(entry);

        self.update_one(&pack_dir, &destination, &rel);
        self.refresh_mods(&pack_dir);
    }

    /// Delete one mod's folder from the mods folder, straight from its row button.
    ///
    /// A mod the pack needs goes through [`ask_to_delete`](Self::ask_to_delete) first, so reaching
    /// here means the player has already been told what deleting it costs.
    fn delete_one(&mut self, index: usize) {
        let Some(destination) = self.destination() else {
            self.warn("Pick the mods folder first.");
            return;
        };

        let Some(entry) = self.mods.get(index) else {
            return;
        };
        let name = entry.name.clone();
        let status = entry.status;
        let required = entry.required;
        // `rel` is the path the install uses, and a mod that *is* its own top-level folder —
        // `AddUtility(REQUIRED_FOR_MODS)`, `Trials Mods` — is that folder. Joining category and
        // name would look for `AddUtility(REQUIRED_FOR_MODS)/AddUtility(REQUIRED_FOR_MODS)`, which
        // is why deleting the required mod never worked.
        let rel = rel_path(entry);
        let target = destination.join(&rel);

        if required {
            self.warn(format!(
                "{name} is required — the pack's other mods call into it. Deleting it anyway; \
                 install it again as soon as you can."
            ));
        }
        if !status.is_installed() {
            self.info(format!("{name} is not installed, so there is nothing to delete."));
            return;
        }

        match fs::remove_dir_all(&target) {
            Ok(()) => {
                self.info(format!("{name}: deleted."));
                self.forget_installed(&[rel]);
            }
            Err(err) => self.warn(format!(
                "{name}: could not delete {}: {err}",
                target.display()
            )),
        }

        let entry = &mut self.mods[index];
        entry.status = Status::NotInstalled;
        entry.changed_files = 0;
        // Nothing on disk any more, so the row drops back to the unticked default — except for a
        // required mod, which stays ticked so the next install puts it back.
        entry.selected = required;
    }

    /// A row's Delete button: a mod the pack needs asks first, everything else just goes.
    ///
    /// `AddUtility` can be deleted — there are reasons to want it gone, a mod conflict being the
    /// obvious one — but the other mods are written against it, so it never goes on one click.
    fn ask_to_delete(&mut self, index: usize) {
        let required = self
            .mods
            .get(index)
            .is_some_and(|entry| entry.required && entry.status.is_installed());

        if required {
            self.confirm_delete = Some(index);
        } else {
            self.delete_one(index);
        }
    }

    /// Top bar: where the pack comes from, where it is written, and the state of the last check.
    fn header(&mut self, ui: &mut egui::Ui, action: &mut Option<Action>) {
        ui.add_space(4.0);

        ui.horizontal(|ui| {
            ui.heading("Ducks Mod Manager");
            ui.label(
                RichText::new("fetches the pack itself — no git needed").weak(),
            );
            ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                if ui.button("Open mods folder").clicked() {
                    *action = Some(Action::OpenFolder);
                }
                if ui.button("Open repo").clicked() {
                    *action = Some(Action::OpenRepo);
                }
            });
        });

        ui.add_space(2.0);
        ui.horizontal(|ui| {
            ui.label("Mods folder:");
            match &self.settings.mods_root {
                Some(root) => {
                    ui.monospace(root.display().to_string());
                }
                None => {
                    ui.colored_label(WARN_COLOR, "not chosen yet");
                }
            }
            if ui.button("Browse…").clicked() {
                *action = Some(Action::Browse);
            }
        });

        ui.horizontal(|ui| {
            ui.label("Writes to:");
            match self.destination() {
                Some(destination) => {
                    ui.monospace(destination.display().to_string());
                }
                None => {
                    ui.weak("pick a mods folder to see the destination");
                }
            }
        });

        ui.add_space(2.0);
        ui.horizontal(|ui| {
            ui.label("Updates:");
            match &self.update {
                UpdateState::Unknown => {
                    ui.label("not checked yet");
                }
                UpdateState::Checking => {
                    ui.spinner();
                    ui.label("checking…");
                }
                UpdateState::UpToDate { version } => {
                    ui.colored_label(OK_COLOR, format!("up to date ({version})"));
                }
                UpdateState::Behind { count } => {
                    ui.colored_label(WARN_COLOR, format!("{count} mod(s) have updates"));
                }
                UpdateState::Failed(message) => {
                    ui.colored_label(ERROR_COLOR, format!("failed: {message}"));
                }
            }

            // Update and snapshot actions, in one row of fixed-width buttons so they line up.
            ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                let can_restore = self.settings.mods_root.is_some() && !self.savestates.is_empty();
                let restore = ui
                    .add_enabled_ui(can_restore, |ui| {
                        ui.add_sized(
                            [BUTTON_WIDE, BUTTON_HEIGHT],
                            egui::Button::new("Restore state"),
                        )
                    })
                    .inner
                    .on_hover_text(
                        "Puts the chosen savestate back into the mods folder. This replaces what is \
                         installed and cannot be undone, so take a savestate first if you are not \
                         sure.",
                    );
                if restore.clicked() {
                    *action = Some(Action::RestoreState);
                }

                // Which savestate Restore puts back, and which one Overwrite rewrites.
                let states = &self.savestates;
                let choice = &mut self.restore_choice;
                ui.add_enabled_ui(can_restore, |ui| {
                    egui::ComboBox::from_id_salt("restore_pick")
                        .selected_text(choice.clone())
                        .width(PICK_WIDTH)
                        .show_ui(ui, |ui| {
                            for state in states {
                                let label = if state.label.is_empty() {
                                    state.stamp.clone()
                                } else {
                                    format!("{} — {}", state.stamp, state.label)
                                };
                                ui.selectable_value(choice, state.stamp.clone(), label);
                            }
                        });
                });

                // Overwrite the savestate the dropdown has picked with what is installed now. It
                // needs the same two things restoring does: a folder to read, and a savestate to
                // rewrite.
                let can_overwrite =
                    can_restore && self.destination().is_some_and(|path| path.is_dir());
                let overwrite = ui
                    .add_enabled_ui(can_overwrite, |ui| {
                        ui.add_sized(
                            [BUTTON_NARROW, BUTTON_HEIGHT],
                            egui::Button::new("Overwrite"),
                        )
                    })
                    .inner
                    .on_hover_text(
                        "Replaces the savestate chosen on its right with the mods that are \
                         installed right now, keeping its name. What that savestate held is gone \
                         for good — Make savestate is the one that never overwrites anything.",
                    );
                if overwrite.clicked() {
                    *action = Some(Action::OverwriteState);
                }

                let can_savestate = self.settings.mods_root.is_some()
                    && self.destination().is_some_and(|path| path.is_dir());
                let savestate = ui
                    .add_enabled_ui(can_savestate, |ui| {
                        ui.add_sized(
                            [BUTTON_WIDE, BUTTON_HEIGHT],
                            egui::Button::new("Make savestate"),
                        )
                    })
                    .inner
                    .on_hover_text(
                        "Zips the installed mods into DucksModManager/savestate, so they can be \
                         put back later. The name box names it; empty uses the date.",
                    );
                if savestate.clicked() {
                    *action = Some(Action::MakeSavestate);
                }

                // The name a savestate is given. Empty means it is named after the date and time.
                ui.add_sized(
                    [BUTTON_WIDE, BUTTON_HEIGHT],
                    egui::TextEdit::singleline(&mut self.savestate_name)
                        .hint_text("savestate name"),
                );

                // Pulling only makes sense once a check has found something to pull.
                let can_pull = matches!(self.update, UpdateState::Behind { .. });
                let pull = ui
                    .add_enabled_ui(can_pull, |ui| {
                        ui.add_sized(
                            [BUTTON_NARROW, BUTTON_HEIGHT],
                            egui::Button::new("Pull update"),
                        )
                    })
                    .inner
                    .on_hover_text(
                        "Savestates the installed mods first, then updates only what is \
                         installed. Mods that are not installed are left alone.",
                    );
                if pull.clicked() {
                    *action = Some(Action::PullUpdate);
                }

                if ui
                    .add_sized(
                        [BUTTON_WIDE, BUTTON_HEIGHT],
                        egui::Button::new("Check for updates"),
                    )
                    .clicked()
                {
                    *action = Some(Action::CheckUpdates);
                }
            });
        });

        ui.add_space(2.0);
        egui::CollapsingHeader::new("Advanced")
            .default_open(false)
            .show(ui, |ui| {
                egui::Grid::new("settings_grid")
                    .num_columns(2)
                    .spacing([10.0, 6.0])
                    .show(ui, |ui| {
                        ui.label("Repository");
                        ui.add(
                            egui::TextEdit::singleline(&mut self.settings.repo_url)
                                .desired_width(460.0),
                        );
                        ui.end_row();

                        ui.label("Branch");
                        ui.add(
                            egui::TextEdit::singleline(&mut self.settings.branch)
                                .desired_width(180.0),
                        );
                        ui.end_row();

                        ui.label("Install folder name");
                        ui.add(
                            egui::TextEdit::singleline(&mut self.settings.install_name)
                                .desired_width(180.0),
                        );
                        ui.end_row();
                    });

                ui.checkbox(
                    &mut self.settings.savestate_before_pull,
                    "Savestate the installed mods before pulling an update",
                );
            });

        ui.add_space(4.0);
    }

    /// Second bar: filtering, selection helpers and the selection count.
    fn toolbar(&mut self, ui: &mut egui::Ui, action: &mut Option<Action>) {
        ui.add_space(4.0);
        ui.horizontal(|ui| {
            ui.label("Filter:");
            ui.add(
                egui::TextEdit::singleline(&mut self.filter)
                    .desired_width(220.0)
                    .hint_text("mod or category"),
            );
            ui.checkbox(&mut self.only_needing_action, "Only needing action");

            ui.separator();
            if ui.button("Select all").clicked() {
                *action = Some(Action::SelectAll);
            }
            if ui.button("Select none").clicked() {
                *action = Some(Action::SelectNone);
            }
            if ui.button("Select needing action").clicked() {
                *action = Some(Action::SelectNeedingAction);
            }

            ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                let selected = self.mods.iter().filter(|entry| entry.selected).count();
                ui.label(
                    RichText::new(format!("{selected} of {} selected", self.mods.len())).strong(),
                );
            });
        });
        ui.add_space(2.0);
    }

    /// The mod list: a fixed header row, then one grid row per mod that survives the filter.
    fn mod_table(&self, ui: &mut egui::Ui, action: &mut Option<Action>) {
        let dark = ui.visuals().dark_mode;
        let filter = self.filter.trim().to_lowercase();

        ui.add_space(4.0);
        ui.horizontal(|ui| {
            column_header(ui, COL_CHECK, "");
            column_header(ui, COL_NAME, "Mod");
            column_header(ui, COL_CATEGORY, "Category");
            column_header(ui, COL_STATUS, "Status");
            column_header(ui, COL_CHANGED, "Changed");
            column_header(ui, COL_ACTIONS, "");
        });
        ui.separator();

        let mut shown = 0usize;
        egui::ScrollArea::vertical()
            .auto_shrink([false, false])
            .show(ui, |ui| {
                egui::Grid::new("mods_grid")
                    .num_columns(6)
                    .min_col_width(0.0)
                    .spacing([COL_SPACING, 3.0])
                    .striped(true)
                    .show(ui, |ui| {
                        for (index, entry) in self.mods.iter().enumerate() {
                            if !filter.is_empty() {
                                let haystack =
                                    format!("{} {}", entry.category, entry.name).to_lowercase();
                                if !haystack.contains(&filter) {
                                    continue;
                                }
                            }
                            if self.only_needing_action && entry.status == Status::UpToDate {
                                continue;
                            }
                            shown += 1;
                            self.mod_row(ui, index, entry, dark, action);
                        }
                    });

                if shown == 0 {
                    ui.add_space(10.0);
                    if self.mods.is_empty() {
                        ui.weak("No mods yet — Check for updates fetches the pack.");
                    } else {
                        ui.weak("Nothing matches the current filter.");
                    }
                }
            });
    }

    /// One mod row. Widgets only read state and push an action, so the row needs no `&mut self`.
    fn mod_row(
        &self,
        ui: &mut egui::Ui,
        index: usize,
        entry: &ModEntry,
        dark: bool,
        action: &mut Option<Action>,
    ) {
        // AddUtility is mandatory, so its box is drawn disabled and can never report a change.
        let mut selected = entry.selected;
        ui.add_enabled_ui(!entry.required, |ui| {
            let response =
                ui.add_sized([COL_CHECK, ROW_HEIGHT], egui::Checkbox::new(&mut selected, ""));
            if response.changed() {
                *action = Some(Action::SetRow(index, selected));
            }
        });

        // A mod is one folder: its sub-folders and helper scripts never become rows of their own.
        let mut name = entry.name.clone();
        if entry.required {
            name.push_str(" (Required)");
        }
        let mut name_text = RichText::new(name);
        if entry.required {
            name_text = name_text.strong();
        }
        ui.add_sized([COL_NAME, ROW_HEIGHT], egui::Label::new(name_text).truncate());

        ui.add_sized(
            [COL_CATEGORY, ROW_HEIGHT],
            egui::Label::new(RichText::new(&entry.category).color(ui.visuals().weak_text_color()))
                .truncate(),
        );

        ui.add_sized(
            [COL_STATUS, ROW_HEIGHT],
            egui::Label::new(RichText::new(entry.status.label()).color(entry.status.color(dark))),
        );

        let changed = if entry.changed_files == 0 {
            "—".to_owned()
        } else {
            entry.changed_files.to_string()
        };
        ui.add_sized([COL_CHANGED, ROW_HEIGHT], egui::Label::new(changed));

        // Per-row actions. Deleting is meaningless for a mod that is not on disk, so that button
        // greys out rather than disappearing. The required mod can be deleted like any other — it
        // just asks for confirmation first, which is why its button stays live.
        let can_install = self.settings.mods_root.is_some();
        let can_delete = entry.status.is_installed();
        ui.allocate_ui_with_layout(
            egui::vec2(COL_ACTIONS, ROW_HEIGHT),
            Layout::left_to_right(Align::Center),
            |ui| {
                if ui
                    .add_enabled(can_install, egui::Button::new("Install").small())
                    .clicked()
                {
                    *action = Some(Action::InstallRow(index));
                }
                let delete = ui.add_enabled(can_delete, egui::Button::new("Delete").small());
                let delete = if entry.required {
                    delete.on_hover_text(
                        "AddUtility is called into by the pack's other mods, so deleting it asks \
                         for confirmation first. The next install puts it back.",
                    )
                } else {
                    delete
                };
                if delete.clicked() {
                    *action = Some(Action::DeleteRow(index));
                }
            },
        );

        ui.end_row();
    }

    /// Bottom bar: the one button that will really copy files once the engine lands.
    fn actions_bar(&mut self, ui: &mut egui::Ui, action: &mut Option<Action>) {
        ui.add_space(4.0);
        ui.horizontal(|ui| {
            let selected = self.mods.iter().filter(|entry| entry.selected).count();
            let ready = selected > 0 && self.settings.mods_root.is_some();
            let label = format!("Install {selected} selected mod(s)");
            if ui.add_enabled(ready, egui::Button::new(label)).clicked() {
                *action = Some(Action::InstallSelected);
            }
            ui.label(
                RichText::new("Installs from the manager's own copy of the pack.").weak(),
            );

            ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                if ui.button("Quit").clicked() {
                    ui.ctx().send_viewport_cmd(egui::ViewportCommand::Close);
                }
            });
        });
        ui.add_space(4.0);
    }

    /// Rolling log of what the buttons did, or will do.
    fn log_panel(&mut self, ui: &mut egui::Ui, action: &mut Option<Action>) {
        ui.add_space(4.0);
        ui.horizontal(|ui| {
            ui.strong("Log");
            ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                if ui.button("Clear").clicked() {
                    *action = Some(Action::ClearLog);
                }
                ui.label(RichText::new(format!("{} line(s)", self.log.len())).weak());
            });
        });
        ui.separator();

        egui::ScrollArea::vertical()
            .stick_to_bottom(true)
            .auto_shrink([false, false])
            .show(ui, |ui| {
                for line in &self.log {
                    let color = match line.level {
                        Level::Info => ui.visuals().text_color(),
                        Level::Warn => WARN_COLOR,
                    };
                    ui.add(egui::Label::new(RichText::new(&line.text).color(color)).wrap());
                }
            });
    }

    /// The panel on the right: the pack's own documentation, out of the pack copy.
    ///
    /// This is the space the mod list never used. The text is whatever the pack shipped — the same
    /// file a player reads on GitHub — so what is on screen always matches the pack that was
    /// fetched. It is read when the pack changes rather than here, because this runs every frame.
    fn docs_panel(&self, ui: &mut egui::Ui, action: &mut Option<Action>) {
        ui.add_space(4.0);
        ui.horizontal(|ui| {
            ui.strong("Modpack Documentation");
            ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                let on_disk = self.doc_path().is_some_and(|path| path.is_file());
                let open = ui
                    .add_enabled(on_disk, egui::Button::new("Open Docs folder"))
                    .on_hover_text("Opens the pack's own Docs folder, with the rest of its files.");
                if open.clicked() {
                    *action = Some(Action::OpenDocs);
                }
            });
        });
        ui.label(
            RichText::new(format!("{}/{}", pack::DOCS_DIR, pack::DOC_FILE))
                .weak()
                .size(11.0),
        );
        ui.separator();

        let Some(text) = self.doc.as_deref() else {
            ui.add_space(6.0);
            ui.label(
                RichText::new(
                    "No documentation on disk yet — Check for updates fetches the pack, and its \
                     documentation comes with it.",
                )
                .color(WARN_COLOR),
            );
            return;
        };

        egui::ScrollArea::vertical()
            .auto_shrink([false, false])
            .show(ui, |ui| {
                for line in doc_lines(text) {
                    doc_line(ui, &line);
                }
            });
    }

    /// Asks before deleting a mod the pack is built around.
    ///
    /// Everything else deletes on one click; this is the one delete that can break mods that are
    /// still installed, so it is the one that stops and asks. The window only ever offers the two
    /// answers: `ForceDeleteRow` goes ahead, anything else — Cancel, the close box, Escape — leaves
    /// the mod alone.
    fn confirm_delete_window(&mut self, ctx: &egui::Context, action: &mut Option<Action>) {
        let Some(index) = self.confirm_delete else {
            return;
        };
        let Some(entry) = self.mods.get(index) else {
            self.confirm_delete = None;
            return;
        };

        let name = entry.name.clone();
        let category = entry.category.clone();
        let mut answer: Option<bool> = None;
        let mut open = true;

        egui::Window::new("Delete a mod the pack needs?")
            .collapsible(false)
            .resizable(false)
            .anchor(egui::Align2::CENTER_CENTER, egui::vec2(0.0, 0.0))
            .open(&mut open)
            .show(ctx, |ui| {
                ui.label(format!(
                    "{name} ({category}) is the mod the pack is built around: other mods call into \
                     it for host checks and shared fixes."
                ));
                ui.add_space(4.0);
                ui.colored_label(
                    WARN_COLOR,
                    "Deleting it can break those mods while it is gone. The folder is removed \
                     outright — the next Install puts it back.",
                );
                ui.add_space(4.0);
                ui.label(
                    RichText::new("Take a savestate first if you want a way back.").weak(),
                );
                ui.add_space(8.0);
                ui.horizontal(|ui| {
                    if ui.button("Delete it anyway").clicked() {
                        answer = Some(true);
                    }
                    if ui.button("Cancel").clicked() {
                        answer = Some(false);
                    }
                });
            });

        match answer {
            Some(true) => {
                self.confirm_delete = None;
                *action = Some(Action::ForceDeleteRow(index));
            }
            Some(false) => {
                self.confirm_delete = None;
                self.info("Deletion cancelled.");
            }
            // Nothing was clicked: the close box counts as a no, and leaving the window up keeps
            // the question on screen.
            None if !open => {
                self.confirm_delete = None;
                self.info("Deletion cancelled.");
            }
            None => {}
        }
    }
}

impl eframe::App for ModManagerApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        // Widgets never mutate the app directly: they push a single action that is applied once the
        // frame has been laid out. That keeps every borrow immutable while the UI is being built.
        let mut action: Option<Action> = None;

        egui::TopBottomPanel::top("header").show(ctx, |ui| self.header(ui, &mut action));
        egui::TopBottomPanel::top("toolbar").show(ctx, |ui| self.toolbar(ui, &mut action));
        egui::TopBottomPanel::bottom("actions").show(ctx, |ui| self.actions_bar(ui, &mut action));
        egui::TopBottomPanel::bottom("log")
            .resizable(true)
            .default_height(180.0)
            .show(ctx, |ui| self.log_panel(ui, &mut action));
        // The pack's documentation fills the room the mod list leaves on the right. Draggable, so
        // anyone who would rather have the list's columns back can have them.
        egui::SidePanel::right("docs")
            .resizable(true)
            .default_width(DOCS_WIDTH)
            .min_width(180.0)
            .show(ctx, |ui| self.docs_panel(ui, &mut action));
        egui::CentralPanel::default().show(ctx, |ui| self.mod_table(ui, &mut action));

        // The confirmation sits on top of everything else, and its answer is handled by the same
        // match below — so a yes deletes on the click that said it.
        self.confirm_delete_window(ctx, &mut action);

        if let Some(action) = action {
            self.handle(action);
        }

        // Autosave: any settings edit lands on disk straight away, but only when it really changed.
        if self.settings != self.saved {
            self.save_settings();
        }
    }
}

/// Reads the `key = value` settings file. `None` means there is nothing readable there yet.
fn read_settings(path: &Path) -> Option<Settings> {
    let text = std::fs::read_to_string(path).ok()?;
    let mut settings = Settings::default();

    for line in text.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let Some((key, value)) = line.split_once('=') else {
            continue;
        };
        let value = value.trim();
        match key.trim() {
            "repo_url" => settings.repo_url = value.to_owned(),
            "branch" => settings.branch = value.to_owned(),
            "install_name" => settings.install_name = value.to_owned(),
            "savestate_before_pull" => settings.savestate_before_pull = read_bool(value),
            // Unknown keys are ignored, so an older build can still read a newer file.
            _ => {}
        }
    }

    Some(settings)
}

/// Writes the settings file, creating the `DucksModManager` folder if it is missing.
fn write_settings(path: &Path, settings: &Settings) -> std::io::Result<()> {
    let mut text =
        String::from("# Ducks Mod Manager settings. Written by the manager; safe to delete.\n");
    text.push_str(&format!("repo_url = {}\n", saver::one_line(&settings.repo_url)));
    text.push_str(&format!("branch = {}\n", saver::one_line(&settings.branch)));
    text.push_str(&format!(
        "install_name = {}\n",
        saver::one_line(&settings.install_name)
    ));
    text.push_str(&format!(
        "savestate_before_pull = {}\n",
        settings.savestate_before_pull
    ));

    write_text(path, &text)
}

/// Writes a small text file, creating its folder if it is missing.
fn write_text(path: &Path, text: &str) -> std::io::Result<()> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    std::fs::write(path, text)
}

/// `DucksModManager` beside the mods folder — one level up from it, never inside it.
///
/// The loader scans the mods folder for `.lua` files, and both the pack copy and the merge bases are
/// full of them, so anything kept inside the mods folder is read as mods in its own right. Beside it,
/// the game never looks at it, and a mods folder picked again still finds the same settings, saves
/// and bases.
fn appdata_dir(mods_root: &Path) -> PathBuf {
    mods_root.parent().unwrap_or(mods_root).join(APPDATA_DIR)
}

/// The pointer's home: beside the executable, because at startup nothing else is known yet.
fn pointer_path() -> Option<PathBuf> {
    let exe = std::env::current_exe().ok()?;
    Some(exe.parent()?.join(POINTER_FILE))
}

/// Reads the mods folder out of the pointer file. An empty file counts as "nothing saved".
fn read_pointer(path: &Path) -> Option<PathBuf> {
    let text = std::fs::read_to_string(path).ok()?;
    let trimmed = text.trim();
    if trimmed.is_empty() {
        return None;
    }
    Some(PathBuf::from(trimmed))
}

/// Writes the mods folder into the pointer file.
fn write_pointer(path: &Path, folder: &Path) -> std::io::Result<()> {
    write_text(path, &format!("{}\n", folder.display()))
}

fn read_bool(value: &str) -> bool {
    matches!(
        value.to_ascii_lowercase().as_str(),
        "true" | "yes" | "1" | "on"
    )
}

/// Fixed-width header cell, sized to match the grid cells below it.
fn column_header(ui: &mut egui::Ui, width: f32, text: &str) {
    ui.add_sized(
        [width, ROW_HEIGHT],
        egui::Label::new(RichText::new(text).strong()),
    );
}

/// Opens a URL in the OS default browser.
fn open_url(url: &str) -> std::io::Result<()> {
    open_with_os(url)
}

/// Opens a folder in the OS file browser.
fn open_path(path: &Path) -> std::io::Result<()> {
    open_with_os(&path.display().to_string())
}

/// Spawns the platform's "open this" launcher and forgets about it: the browser or file manager
/// outlives the manager, so there is nothing to wait on.
fn open_with_os(target: &str) -> std::io::Result<()> {
    #[cfg(target_os = "windows")]
    let program = "explorer";
    #[cfg(target_os = "macos")]
    let program = "open";
    #[cfg(all(unix, not(target_os = "macos")))]
    let program = "xdg-open";

    std::process::Command::new(program).arg(target).spawn()?;
    Ok(())
}

/// One line of the pack's documentation, with the little Markdown it uses read off.
///
/// There is no Markdown renderer in the build, and this one file is the only Markdown there is: the
/// few shapes it actually writes — `**headings**`, `- bullets`, sub-bullets indented by a tab or
/// four spaces, and the backslash Markdown puts at the end of a line — are handled here rather than
/// pulled in as a dependency. Anything else is shown exactly as written.
enum DocLine {
    /// A blank line, kept so paragraphs stay apart.
    Gap,
    /// `**Like this:**`, and any text that followed it on the same line.
    Heading { lead: String, rest: String },
    /// `- ...`, at its indent level, with the `*Name:*` a bullet usually opens with split off.
    Bullet {
        depth: usize,
        lead: Option<String>,
        rest: String,
    },
    /// Anything else, as it was written.
    Plain(String),
}

/// Reads the documentation's text into lines the panel knows how to draw.
fn doc_lines(text: &str) -> Vec<DocLine> {
    text.lines().map(parse_doc_line).collect()
}

/// Works out one line's shape. Every rule here is one the pack's own file relies on.
fn parse_doc_line(line: &str) -> DocLine {
    // A backslash at the end of a line is Markdown's "break here", which means nothing on screen.
    let line = line.strip_suffix('\\').unwrap_or(line).trim_end();
    if line.is_empty() {
        return DocLine::Gap;
    }

    let indent: String = line
        .chars()
        .take_while(|letter| *letter == ' ' || *letter == '\t')
        .collect();
    // A tab is one level in, four spaces are one level in: the file uses both for sub-bullets.
    let depth = indent.matches('\t').count() + indent.matches(' ').count() / 4;
    let body = &line[indent.len()..];

    if let Some(rest) = body.strip_prefix("- ") {
        let (lead, rest) = doc_lead(rest.trim_start());
        return DocLine::Bullet { depth, lead, rest };
    }

    if let Some((lead, rest)) = bold_lead(body) {
        return DocLine::Heading { lead, rest };
    }

    // A line that opens with `*Name:*` but no dash is still a description — the file's AddUtility
    // entry and its credits line are written that way — so it is drawn as a bullet too, which is
    // what loses the asterisks.
    if let (Some(lead), rest) = doc_lead(body)
        && !lead.is_empty()
    {
        return DocLine::Bullet {
            depth,
            lead: Some(lead),
            rest,
        };
    }

    DocLine::Plain(body.to_owned())
}

/// Splits a leading `**bold**` off a line, and returns it with whatever followed it.
fn bold_lead(text: &str) -> Option<(String, String)> {
    let after = text.strip_prefix("**")?;
    let (lead, rest) = after.split_once("**")?;

    Some((lead.trim().to_owned(), rest.trim_start().to_owned()))
}

/// Splits the `*Name:*` a line opens with off the rest of it. A line that has none — a plain
/// sub-bullet such as `- (do not do this)` — comes back whole, with no lead.
fn doc_lead(text: &str) -> (Option<String>, String) {
    let Some(after) = text.strip_prefix('*') else {
        return (None, text.to_owned());
    };

    match after.split_once('*') {
        Some((lead, rest)) => (Some(lead.trim().to_owned()), rest.trim_start().to_owned()),
        None => (None, text.to_owned()),
    }
}

/// Draws one parsed documentation line.
fn doc_line(ui: &mut egui::Ui, line: &DocLine) {
    match line {
        DocLine::Gap => {
            ui.add_space(6.0);
        }
        DocLine::Heading { lead, rest } => {
            ui.horizontal_wrapped(|ui| {
                ui.label(RichText::new(lead).strong().size(15.0));
                if !rest.is_empty() {
                    ui.label(RichText::new(rest));
                }
            });
        }
        DocLine::Bullet { depth, lead, rest } => {
            ui.horizontal_wrapped(|ui| {
                // Sub-bullets sit in under their parent, the way the file indents them.
                ui.add_space(14.0 * *depth as f32);
                ui.label(RichText::new("•").weak());
                if let Some(lead) = lead {
                    ui.label(RichText::new(lead).strong());
                }
                if !rest.is_empty() {
                    ui.label(RichText::new(rest));
                }
            });
        }
        DocLine::Plain(text) => {
            ui.label(RichText::new(text));
        }
    }
}


#[cfg(test)]
mod tests {
    use super::*;

    fn temp_path(name: &str) -> PathBuf {
        std::env::temp_dir().join(name).join(SETTINGS_FILE)
    }

    /// The manager's own folder sits beside the mods folder, not inside it: the loader reads `.lua`
    /// files out of the mods folder, and the pack copy and merge bases are nothing but `.lua` files.
    #[test]
    fn appdata_sits_beside_the_mods_folder() {
        let mods = Path::new("/games/BITESQUID/Gauntlet/mods");

        assert_eq!(
            appdata_dir(mods),
            Path::new("/games/BITESQUID/Gauntlet/DucksModManager")
        );

        // A root with nothing above it still gets a folder rather than no answer at all.
        assert_eq!(appdata_dir(Path::new("/")), Path::new("/DucksModManager"));
    }

    /// The settings file is the only thing that makes choices stick between launches, so it has to
    /// survive a write/read round trip.
    #[test]
    fn settings_round_trip() {
        let path = temp_path("ducksmm_settings_round_trip");
        let settings = Settings {
            repo_url: "https://example.invalid/pack.git".to_owned(),
            branch: "testing".to_owned(),
            mods_root: None,
            install_name: "Ducks Mods".to_owned(),
            savestate_before_pull: true,
        };

        write_settings(&path, &settings).expect("write settings");
        let loaded = read_settings(&path).expect("read the settings back");

        assert_eq!(loaded.repo_url, settings.repo_url);
        assert_eq!(loaded.branch, settings.branch);
        assert_eq!(loaded.install_name, settings.install_name);
        assert_eq!(loaded.savestate_before_pull, settings.savestate_before_pull);

        // The file is meant to be readable and hand-editable, so pin its shape too.
        let text = std::fs::read_to_string(&path).expect("read the raw file");
        assert!(text.starts_with("# Ducks Mod Manager settings."));
        assert!(text.contains("repo_url = https://example.invalid/pack.git\n"));
        assert!(text.contains("branch = testing\n"));
        assert!(text.contains("savestate_before_pull = true\n"));

        std::fs::remove_dir_all(path.parent().unwrap()).ok();
    }

    /// No file just means the folder has not been used before, which is not an error.
    #[test]
    fn missing_file_reads_as_none() {
        assert!(read_settings(&temp_path("ducksmm_settings_absent")).is_none());
    }

    #[test]
    fn bools_are_forgiving() {
        assert!(read_bool("TRUE"));
        assert!(read_bool("Yes"));
        assert!(read_bool("1"));
        assert!(!read_bool("false"));
        assert!(!read_bool("off"));
    }

    /// The documentation panel's line reader, against the shapes the pack's own file uses. Every
    /// line of the sample is written the way `Modpack Documentation (READ THIS).md` writes it.
    #[test]
    fn documentation_lines_are_read_the_way_the_file_writes_them() {
        let text = [
            "**Ducks Modpack Documentation:** \\",
            "",
            "*Credits:* Skapp, Hoyt. \\",
            "**Local Mods:**",
            "- *DucksUI:* menu settings",
            "\t- (do not do this)",
            "    - indented by four spaces",
            "just prose",
        ]
        .join("\n");
        let parsed = doc_lines(&text);

        assert!(matches!(
            &parsed[0],
            DocLine::Heading { lead, rest }
                if lead.as_str() == "Ducks Modpack Documentation:" && rest.is_empty()
        ));
        assert!(matches!(parsed[1], DocLine::Gap));

        // A description line with no dash is still a description, so it keeps its name split off.
        assert!(matches!(
            &parsed[2],
            DocLine::Bullet { depth: 0, lead: Some(lead), rest }
                if lead.as_str() == "Credits:" && rest == "Skapp, Hoyt."
        ));
        assert!(matches!(
            &parsed[3],
            DocLine::Heading { lead, .. } if lead.as_str() == "Local Mods:"
        ));
        assert!(matches!(
            &parsed[4],
            DocLine::Bullet { depth: 0, lead: Some(lead), rest }
                if lead.as_str() == "DucksUI:" && rest == "menu settings"
        ));

        // Both ways the file indents a sub-bullet count as one level in, and neither has a name.
        assert!(matches!(
            &parsed[5],
            DocLine::Bullet { depth: 1, lead: None, rest } if rest == "(do not do this)"
        ));
        assert!(matches!(
            &parsed[6],
            DocLine::Bullet { depth: 1, lead: None, rest } if rest == "indented by four spaces"
        ));

        assert!(matches!(&parsed[7], DocLine::Plain(text) if text == "just prose"));
    }

    /// A blank line is a gap, not an empty label — and a trailing backslash is not shown.
    #[test]
    fn documentation_blank_lines_become_gaps() {
        assert!(matches!(doc_lines("   ")[0], DocLine::Gap));
        // An empty file is simply no lines at all, which the panel draws as nothing.
        assert!(doc_lines("").is_empty());
        assert!(matches!(&doc_lines("text \\")[0], DocLine::Plain(text) if text == "text"));
    }

    /// The pointer is what leads the manager back to its appdata folder, so it has to round trip.
    #[test]
    fn pointer_round_trip() {
        let path = std::env::temp_dir()
            .join("ducksmm_pointer_round_trip")
            .join(POINTER_FILE);
        let folder = PathBuf::from("/some/mods/folder");

        write_pointer(&path, &folder).expect("write the pointer");
        assert_eq!(read_pointer(&path).as_deref(), Some(folder.as_path()));

        std::fs::remove_dir_all(path.parent().unwrap()).ok();
    }

    /// A missing or blank pointer just means "nothing chosen yet", which is not an error.
    #[test]
    fn pointer_without_a_path_reads_as_none() {
        let path = std::env::temp_dir()
            .join("ducksmm_pointer_blank")
            .join(POINTER_FILE);

        assert!(read_pointer(&path).is_none());
        write_pointer(&path, Path::new("")).expect("write a blank pointer");
        assert!(read_pointer(&path).is_none());

        std::fs::remove_dir_all(path.parent().unwrap()).ok();
    }
}
