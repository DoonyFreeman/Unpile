# Unpile 0.6.0 — local beta candidate

Review files with two-finger horizontal swipes over the card: left marks a candidate, right keeps it. Decisions occur on release. Short/cancelled gestures, vertical scrolling, and momentum cannot decide another file. Buttons, mouse drag, and keyboard shortcuts remain available.

The review screen now has layered cards, colored gesture feedback, a softer background, and a fixed glass decision dock. Actions stay visible in compact windows. Reduce Motion avoids card displacement and rotation.

This local build includes all previous saved-session, preview, localization, and confirmed system-Trash features. No file moves directly from a swipe; review the list and confirm separately.

27 checks include gesture-sequence regression coverage. On 11 October 2026, the user confirmed both two-finger swipe directions in the final 0.6.0 demo on a physical trackpad. The extended gesture walkthrough (short gestures, momentum, both Natural Scrolling settings, and preview/settings) remains open, alongside older macOS, physical Intel, downloaded-app first opening, and spoken VoiceOver QA.

The Universal DMG uses a free ad hoc signature and is not notarized. Follow [Apple's per-app opening instructions](https://support.apple.com/en-us/102445) when required. Temporary beta 0.6 has a separate app identity and does not migrate earlier beta sessions.

These notes describe a local candidate, with no public tag or published GitHub download claimed. Adjacent SHA-256 and source manifest identify the reviewed artifact.
