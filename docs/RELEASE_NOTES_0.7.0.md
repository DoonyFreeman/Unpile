# Unpile 0.7.0 beta — review your Downloads with a swipe

Keep what you need, mark the rest, and review the list before moving files to Trash. Unpile is a free, native macOS app with two-finger trackpad swipes, file previews, saved sessions, Undo before transfer, and English/Russian UI. Files stay local; there are no accounts or analytics.

## Download and install

Choose **Unpile-0.7.0-universal.dmg** from this release's assets. The automatically generated Source code archives are for building the project, not installing the app. Open the DMG, drag Unpile to Applications, and launch it. Try the synthetic demo before choosing a real folder.

This free build has an ad hoc signature and is **not notarized**. macOS may require its per-app opening process; follow [Apple's instructions](https://support.apple.com/en-us/102445). No paid Apple membership is required to use or build Unpile.

## What to try

- Move two fingers horizontally over a card without clicking: left marks a candidate, right keeps it. Buttons and keyboard shortcuts are also available.
- Use Later for uncertain files and Undo to change a decision before transfer.
- Review the candidate list, exclude anything you want to keep, and confirm the move separately.
- Resume a real folder's review after closing the app.

Moving files to Trash does not necessarily free disk space immediately. Unpile never empties Trash. Restore moved files through Finder's Trash; Undo applies to decisions before transfer.

## Changes and checks

0.7.0 introduces the permanent app identity `io.github.doonyfreeman.unpile` and records a clean source commit in the artifact manifest. Gesture and file-handling behavior is unchanged from 0.6.0. Sessions from earlier local betas are not automatically imported. Ad hoc update compatibility still needs a separate test.

27 checks pass in native debug/release and Intel release through Rosetta. The Universal bundle, sandbox, signature, resources, DMG integrity, and isolated copy are checked. GUI testing covers Apple Silicon on macOS 27. The user confirmed both physical trackpad swipe directions in 0.6.0; the extended hardware gesture walkthrough remains open.

The build declares macOS 14 as its minimum and includes arm64/x86_64. Older macOS and physical Intel GUI are **not yet validated**. Spoken VoiceOver, a wider media-codec matrix, clean browser-download/quarantine installation, and the Finder installer appearance remain open checks. This is a beta, not a stable compatibility claim.

The SHA-256 and source manifest are attached alongside the DMG. Report ordinary bugs with synthetic examples. Use the repository's private vulnerability-reporting channel for file-safety or security issues; do not share real filenames or file contents publicly.

If Unpile helps you, a GitHub star helps others find it. Feedback about installation and the first review is especially useful.

---

Publication draft: use this body only after the reviewed artifact is approved and uploaded. At preparation time, there is no public release or configured reporting channel.
