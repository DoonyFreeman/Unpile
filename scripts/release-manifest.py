"""Record the reviewed artifact and source content without host paths or user data."""
from pathlib import Path
import hashlib
import json
import plistlib
import subprocess
import sys

dmg, app = map(Path, sys.argv[1:3])
root = Path(__file__).resolve().parent.parent
info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
files = []
for folder in ["Sources", "Tests", "Resources", "scripts", "docs", ".github"]:
    if (root / folder).exists(): files.extend(p for p in (root / folder).rglob("*") if p.is_file() and p.name != ".DS_Store")
for name in ["Package.swift", "README.md", "README.ru.md", "LICENSE", "CHANGELOG.md", "CONTRIBUTING.md", "SECURITY.md", "CODE_OF_CONDUCT.md", ".gitignore"]:
    if (root / name).is_file(): files.append(root / name)
source_files = {str(p.relative_to(root)): digest(p) for p in sorted(files)}
source_digest = hashlib.sha256(json.dumps(source_files, sort_keys=True).encode()).hexdigest()
revision = None
status = subprocess.run(["git", "status", "--porcelain", "--untracked-files=normal"], cwd=root,
    capture_output=True, text=True)
if status.returncode == 0 and not status.stdout.strip():
    tracked = subprocess.run(["git", "ls-files", "-z"], cwd=root, capture_output=True, text=True)
    head = subprocess.run(["git", "rev-parse", "--verify", "HEAD"], cwd=root,
        capture_output=True, text=True)
    if tracked.returncode == 0 and head.returncode == 0 and set(source_files) <= set(tracked.stdout.split("\0")):
        revision = head.stdout.strip()
manifest = {"version": info["CFBundleShortVersionString"], "status": "local-beta-not-published",
    "bundle_id": info["CFBundleIdentifier"], "minimum_macos_declared": info["LSMinimumSystemVersion"],
    "architectures": subprocess.check_output(["lipo", "-archs", str(app / "Contents/MacOS/Unpile")], text=True).split(),
    "signing": "ad-hoc", "notarized": False, "dmg": dmg.name, "dmg_sha256": digest(dmg),
    "executable_sha256": digest(app / "Contents/MacOS/Unpile"), "source_tree_sha256": source_digest,
    "source_files": source_files, "source_revision": revision,
    "source_tree_state": "clean-commit" if revision else "working-tree"}
dmg.with_suffix(".manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
dmg.with_suffix(".sha256").write_text(f"{digest(dmg)}  {dmg.name}\n")
print("PASS: SHA-256 and source manifest recorded")
