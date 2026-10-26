set -eu

cd "$(dirname "$0")"

name=ducksmodmanager
dist=dist
windows_target=x86_64-pc-windows-gnu

cargo build --release
cargo build --release --target "$windows_target"

mkdir -p "$dist"
cp "target/release/$name" "$dist/DucksModManager-linux-x86_64"
cp "target/$windows_target/release/$name.exe" "$dist/DucksModManager-windows-x86_64.exe"

ls -l "$dist"
