set -eu

cd "$(dirname "$0")"

name=ducksmodmanager
crate=DucksModManager
windows_target=x86_64-pc-windows-gnu

cargo build --release --manifest-path "$crate/Cargo.toml"
cargo build --release --manifest-path "$crate/Cargo.toml" --target "$windows_target"

mkdir -p dist
cp "$crate/target/release/$name" "dist/DucksModManager-linux-x86_64"
cp "$crate/target/$windows_target/release/$name.exe" "dist/DucksModManager-windows-x86_64.exe"

ls -l dist
