// Release builds are GUI-only on Windows: without this the exe drags a console window along.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod install;
mod pack;
mod saver;
mod ui;

fn main() -> Result<(), eframe::Error> {
    let options = eframe::NativeOptions {
        viewport: eframe::egui::ViewportBuilder::default()
            .with_title("Ducks Mod Manager")
            .with_inner_size([1120.0, 720.0])
            .with_min_inner_size([860.0, 520.0]),
        ..Default::default()
    };

    eframe::run_native(
        "Ducks Mod Manager",
        options,
        Box::new(|cc| Ok(Box::new(ui::ModManagerApp::new(cc)))),
    )
}



