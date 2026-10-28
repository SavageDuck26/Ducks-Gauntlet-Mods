set -eu

cd "$(dirname "$0")"

name=ducksmodmanager
crate=DucksModManager
windows_target=x86_64-pc-windows-gnu

cargo build --release --manifest-path "$crate/Cargo.toml"
cargo build --release --manifest-path "$crate/Cargo.toml" --target "$windows_target"

mkdir -p dist

# Copy beside the target and rename over it: writing straight into a binary that is currently
# running fails with "Text file busy", and a rename replaces it cleanly even then.
copy_into() {
    cp "$1" "dist/.$2.new"
    mv -f "dist/.$2.new" "dist/$2"
}

copy_into "$crate/target/release/$name" DucksModManager-linux-x86_64
copy_into "$crate/target/$windows_target/release/$name.exe" DucksModManager-windows-x86_64.exe

ls -l dist
