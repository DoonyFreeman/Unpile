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
        *) printf 'Usage: bash scripts/build-app.sh [--qa] [--universal]\n' >&2; exit 64 ;;
    esac
done
if $task_universal; then
    swift build -c release --product Unpile --scratch-path "$task_root/.build/universal-arm64" --triple arm64-apple-macosx14.0 -Xswiftc -gnone
    task_bin="$(swift build -c release --scratch-path "$task_root/.build/universal-arm64" --triple arm64-apple-macosx14.0 --show-bin-path)"
    swift build -c release --product Unpile --scratch-path "$task_root/.build/universal-x86_64" --triple x86_64-apple-macosx14.0 -Xswiftc -gnone
    task_intel="$(swift build -c release --scratch-path "$task_root/.build/universal-x86_64" --triple x86_64-apple-macosx14.0 --show-bin-path)"
else
    swift build -c release --product Unpile -Xswiftc -gnone
    task_bin="$(swift build -c release --show-bin-path)"
fi
task_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$task_root/Resources/Info.plist")"
task_name="Unpile-$task_version"
if $task_qa; then task_name="Unpile-QA-$task_version"; fi
if $task_universal; then task_name="$task_name-universal"; fi
task_app="$task_root/build/$task_name.app"
mkdir -p "$task_app/Contents/MacOS" "$task_app/Contents/Resources"
if $task_universal; then lipo -create "$task_bin/Unpile" "$task_intel/Unpile" -output "$task_app/Contents/MacOS/Unpile"
else cp "$task_bin/Unpile" "$task_app/Contents/MacOS/Unpile"; fi
cp "$task_root/Resources/Info.plist" "$task_app/Contents/Info.plist"
cp "$task_root/LICENSE" "$task_app/Contents/Resources/LICENSE.txt"
cp -R "$task_bin/Unpile_UnpileCore.bundle" "$task_app/Contents/Resources/"
swift scripts/render-brand.swift "$task_root/build/brand"
iconutil -c icns "$task_root/build/brand/AppIcon.iconset" -o "$task_app/Contents/Resources/AppIcon.icns"
if $task_qa; then
    /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier io.github.doonyfreeman.unpile.qa' "$task_app/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName Unpile QA $task_version" "$task_app/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Unpile QA $task_version" "$task_app/Contents/Info.plist"
fi
codesign --force --sign - --entitlements "$task_root/Resources/Unpile.entitlements" "$task_app"
codesign --verify --strict "$task_app"
printf '%s\n' "$task_app"
