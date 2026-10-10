# Unpile 0.5.0 — beta candidate

Review your Downloads one file at a time. Keep useful files, defer uncertain ones, and move confirmed candidates to system Trash.

## Included

- Native macOS cards and previews, keyboard shortcuts, and decision-only Undo.
- Saved sessions, version checks, candidate review, per-file transfer outcomes, and interrupted-operation handling.
- English/Russian interface with live switching.
- Original icon and a Universal drag-to-Applications disk image.
- Local processing with no account, analytics, or file uploads.
- Demo feedback accurately distinguishes temporary decisions from saved folder reviews.

## Installation

Open the DMG and drag Unpile.app to Applications. Eject the image and open the copied app. Choose a folder or try the synthetic demo.

This build has a free ad hoc signature and is not notarized. macOS may require its per-app opening flow; follow [Apple's instructions](https://support.apple.com/en-us/102445). Global security settings are not changed by Unpile.

## Compatibility and limits

The binary contains arm64 and x86_64 code. GUI testing is on Apple Silicon/macOS 27, including launch from the final DMG and from an isolated copied app, branding, demo decisions, compact layout, and both languages. 22 Intel core checks pass under Rosetta. Physical Intel and macOS 14 device validation are still needed. macOS 14 is the declared deployment target, not a fully verified support promise.

Finder installer appearance and a browser-downloaded copy's first opening on a clean device still need validation.

Files stay in place until the candidate list is confirmed. Restore files through Finder's Trash. Unpile never empties Trash. Metadata checks and file coordination cannot eliminate every race with another process.

Full spoken VoiceOver validation and a broader media-codec pilot remain pre-v1 checks. Temporary beta containers do not migrate earlier session data automatically.

## Artifact verification

The adjacent SHA-256 file verifies the DMG. The manifest records the executable, architecture list, signing mode, and source-tree digest. Source ZIP archives alone are not the macOS application.

These are prepared notes for a local candidate. No repository URL, published tag, download count, or final release approval is claimed.
