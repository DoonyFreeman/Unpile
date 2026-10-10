# Changelog

## 0.7.0 — local beta candidate, unpublished

- Use the permanent `io.github.doonyfreeman.unpile` app identity and a separate QA identity. Earlier local beta sessions are not imported.
- Record the source commit in the release manifest only when the working tree is clean.
- Prepare the first GitHub beta review package and short demo script; publication still requires approval.
- Gesture and file-handling behavior is unchanged from 0.6.0.

## 0.6.0 — local beta, unpublished

- Two-finger trackpad swipes with release thresholds, axis locking, cancellation, Natural Scrolling normalization, and momentum guards.
- Gesture decisions are tied to the current file; previews and modal states block hidden decisions.
- Layered cards, colored swipe stamps, spring return, and a fixed glass decision dock.
- Five regression checks for swipe sequences; hardware validation is tracked separately.

## 0.5.0 — local beta, unpublished

- Original app icon and matching in-app branding.
- Universal packaging for Apple Silicon and Intel.
- Drag-to-Applications DMG, bundled installation guidance, SHA-256, and source manifest.
- App verification for signature, sandbox, architectures, icon, localization resources, and data boundaries.
- Contribution, security, community, issue, and pull-request documents; proposed MIT license.
- Hosted checks and a manual candidate build workflow, prepared locally and not run on GitHub yet.

## 0.4.0 — local beta

- English/Russian interface and live language selection.
- System Quick Look for supported local previews, including PDF pages and audio controls.
- Accessibility descriptions and modal keyboard guards.
- Packaged localization resources, portable app launch, and removal of host paths from the distributed executable.

## 0.3.0 — local beta

- Saved review sessions, decisions, and Undo.
- Keep memory across sessions, reconsideration, and 20/50/100 file limits.
- Atomic state storage and explicit handling of write failures or corrupted state.

## 0.2.0 — local beta

- Confirmed system Trash operations, per-file outcomes, cancellation, and recovery journal.

## 0.1.0 — local prototype

- Native cards, folder access, metadata, thumbnails, decisions, Undo, and synthetic demo.
