"""Pull the latest Ducks-Gauntlet-Mods release into a Ducks Mods folder."""

import json
import subprocess
from pathlib import Path

REPO = "SavageDuck26/Ducks-Gauntlet-Mods"
SCRIPT_DIR = Path(__file__).resolve().parent
TARGET_DIR = SCRIPT_DIR


def curl(url):
    return subprocess.run(
        ["curl", "-sSL", url], capture_output=True, text=True, check=True
    ).stdout


def main():
    release = json.loads(curl(f"https://api.github.com/repos/{REPO}/releases/latest"))
    asset = release["assets"][0]

    TARGET_DIR.mkdir(exist_ok=True)

    print(f"Downloading {asset['name']}.")
    archive = TARGET_DIR / asset["name"]
    subprocess.run(
        ["curl", "-sSL", "-o", str(archive), asset["browser_download_url"]], check=True
    )

    print(f"Downloaded Modpack{release['tag_name']}.")


if __name__ == "__main__":
    main()
