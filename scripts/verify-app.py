"""Validate a local .app without reading any user's review state."""
from pathlib import Path
import argparse
import plistlib
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("app", type=Path)
parser.add_argument("--universal", action="store_true")
args = parser.parse_args()
app = args.app.resolve()
info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
executable = app / "Contents/MacOS" / info["CFBundleExecutable"]
assert executable.is_file() and not executable.is_symlink()
arches = set(subprocess.check_output(["lipo", "-archs", str(executable)], text=True).split())
if args.universal:
    assert arches == {"arm64", "x86_64"}
else:
    assert arches and arches <= {"arm64", "x86_64"}
subprocess.run(["codesign", "--verify", "--strict", str(app)], check=True)
signature = subprocess.run(["codesign", "-d", "--entitlements", ":-", str(app)], check=True, capture_output=True)
entitlements = plistlib.loads(signature.stdout)
assert entitlements.get("com.apple.security.app-sandbox") is True
assert entitlements.get("com.apple.security.files.user-selected.read-write") is True
assert entitlements.get("com.apple.security.files.bookmarks.app-scope") is True
assert not entitlements.get("com.apple.security.get-task-allow")
assert not entitlements.get("com.apple.security.network.client")
resources = app / "Contents/Resources"
assert "MIT License" in (resources / "LICENSE.txt").read_text()
assert (resources / "AppIcon.icns").read_bytes().startswith(b"icns")
assert info["CFBundleIconFile"] == "AppIcon"
for language in ("en", "ru"):
    catalog = resources / "Unpile_UnpileCore.bundle" / f"{language}.lproj/Localizable.strings"
    subprocess.run(["plutil", "-lint", str(catalog)], check=True, capture_output=True)
for item in app.rglob("*"):
    assert item.name not in {"folder.bookmark", "review-state.json", "trash-journal.json"}
data = executable.read_bytes()
root = Path(__file__).resolve().parent.parent
assert str(root).encode() not in data and str(Path.home()).encode() not in data
print(f"PASS: app {info['CFBundleShortVersionString']}, architectures {', '.join(sorted(arches))}, signature, sandbox, icon, resources and data boundaries")
