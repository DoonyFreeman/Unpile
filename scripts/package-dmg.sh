#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$task_root"
task_qa=false
task_universal=false
for task_option in "$@"; do
    case "$task_option" in
        --qa) task_qa=true ;;
        --universal) task_universal=true ;;
        *) printf 'Usage: bash scripts/package-dmg.sh [--qa] [--universal]\n' >&2; exit 64 ;;
    esac
done
bash scripts/build-app.sh "$@"
task_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
task_stem="Unpile-$task_version"
task_inner="Unpile.app"
if $task_qa; then task_stem="Unpile-QA-$task_version"; task_inner="Unpile QA.app"; fi
if $task_universal; then task_stem="$task_stem-universal"; fi
task_app="$task_root/build/$task_stem.app"
task_verify=()
if $task_universal; then task_verify=(--universal); fi
python3 scripts/verify-app.py "$task_app" "${task_verify[@]}"

# Isolated, pinned build dependencies. They are not copied into the image.
task_env="$task_root/.build/dmg-tools"
if [ ! -x "$task_env/bin/python" ]; then python3 -m venv "$task_env"; fi
"$task_env/bin/python" -m pip install --disable-pip-version-check --only-binary=:all: --require-hashes -r scripts/dmg-requirements.txt

task_tmp="$(mktemp -d "$task_root/build/dmg-work.XXXXXX")"
task_mount=""
task_mounted=false
function task_cleanup() {
    if $task_mounted; then
        if ! hdiutil detach "$task_mount" >/dev/null; then
            printf 'Build volume remains mounted; preserved temporary files for safe cleanup.\n' >&2
            return
        fi
    fi
    # Only this invocation's own mktemp directory is removed.
    rm -rf "$task_tmp"
}
trap task_cleanup EXIT
task_stage="$task_tmp/stage"
mkdir -p "$task_stage/.background" "$task_root/build/releases"
ditto "$task_app" "$task_stage/$task_inner"
cp build/brand/dmg-background@2x.png "$task_stage/.background/background.png"
cp docs/INSTALL.txt "$task_stage/INSTALL.txt"
ln -s /Applications "$task_stage/Applications"
printf 'Unpile disk-image build' > "$task_stage/.unpile-dmg-build"
hdiutil create -size 96m -fs HFS+ -format UDRW -volname "Unpile $task_version" -srcfolder "$task_stage" -ov "$task_tmp/writable.dmg"
hdiutil attach "$task_tmp/writable.dmg" -nobrowse -noautoopen -plist > "$task_tmp/attached.plist"
task_mount="$(python3 - "$task_tmp/attached.plist" <<'PY'
import plistlib,sys
with open(sys.argv[1], 'rb') as stream:
    info=plistlib.load(stream)
print(next(entity['mount-point'] for entity in info['system-entities'] if 'mount-point' in entity))
PY
)"
task_mounted=true
"$task_env/bin/python" scripts/layout-dmg.py "$task_mount" "$task_inner"
hdiutil detach "$task_mount" >/dev/null
task_mounted=false
task_dmg="$task_root/build/releases/$task_stem.dmg"
hdiutil convert "$task_tmp/writable.dmg" -format UDZO -imagekey zlib-level=9 -ov -o "$task_dmg"
hdiutil verify "$task_dmg"
python3 scripts/release-manifest.py "$task_dmg" "$task_app"
printf '%s\n' "$task_dmg"
