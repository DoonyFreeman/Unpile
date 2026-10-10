"""Set Finder layout only inside the freshly mounted build image."""
from pathlib import Path
import argparse
from ds_store import DSStore
from mac_alias import Alias

parser = argparse.ArgumentParser()
parser.add_argument("volume", type=Path)
parser.add_argument("app_name")
args = parser.parse_args()
root = args.volume.resolve()
assert (root / ".unpile-dmg-build").read_text() == "Unpile disk-image build"
assert (root / args.app_name).is_dir() and (root / "Applications").is_symlink()
background = Alias.for_file(str(root / ".background/background.png")).to_bytes()
with DSStore.open(str(root / ".DS_Store"), "w+") as store:
    store["."]["bwsp"] = {"ShowToolbar": False, "ShowStatusBar": False, "ShowSidebar": False,
        "ShowPathbar": False, "ShowTabView": False, "WindowBounds": "{{180, 140}, {760, 480}}"}
    store["."]["icvp"] = {"viewOptionsVersion": 1, "backgroundType": 2,
        "backgroundImageAlias": background, "iconSize": 128.0, "gridSpacing": 100.0,
        "gridOffsetX": 0.0, "gridOffsetY": 0.0, "textSize": 14.0, "labelOnBottom": True,
        "showItemInfo": False, "showIconPreview": True, "arrangeBy": "none"}
    store["."]["vSrn"] = ("long", 1)
    store["."]["icvl"] = ("type", b"icnv")
    store[args.app_name]["Iloc"] = (200, 255)
    store["Applications"]["Iloc"] = (560, 255)
    store["INSTALL.txt"]["Iloc"] = (665, 405)
print("PASS: Finder layout created inside the build volume")
