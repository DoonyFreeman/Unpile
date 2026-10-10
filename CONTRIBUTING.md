# Contributing to Unpile

Unpile is an open-source beta in [DoonyFreeman/Unpile](https://github.com/DoonyFreeman/Unpile). Use Issues for ordinary bugs and feature requests; use the private route in [SECURITY.md](SECURITY.md) for security or file-safety reports.

## Build and check

Use macOS and Apple Command Line Tools with Swift 6+.

```sh
swift run UnpileChecks
bash scripts/build-app.sh --qa
python3 scripts/verify-app.py build/Unpile-QA-0.7.0.app
```

For both architectures:

```sh
bash scripts/build-app.sh --qa --universal
python3 scripts/verify-app.py build/Unpile-QA-0.7.0-universal.app --universal
```

DMG packaging requires Python 3.10+. It uses two hash-pinned Python build tools in `.build/dmg-tools`; they are not runtime dependencies. The first setup downloads these tools.

```sh
bash scripts/package-dmg.sh --qa --universal
```

## Changes worth contributing

Translations, accessibility fixes, synthetic preview fixtures, installation feedback, and device compatibility reports are useful starting points. Discuss larger behavior changes before implementing them.

Keep changes focused. Explain the user-visible result and relevant verification. Check affected flows locally; add meaningful regression coverage for session or filesystem behavior. Do not add tests that only restate a visual constant.

## File-handling rules

- Test with newly created synthetic directories. Never point tests at actual Downloads, documents, or shared data.
- A swipe changes a decision. It never moves a file directly.
- Use system Trash after explicit list confirmation; preserve version and folder checks. Never add a permanent-delete fallback or automatic Trash emptying.
- Preserve the recovery journal before filesystem operations. Interrupted operations are not automatically repeated.
- Keep paths, names, contents, and thumbnails out of logs, screenshots, reports, and artifacts unless they are synthetic.
- Review both English and Russian catalogs. Placeholder types must match.

The hosted workflow uses read-only repository permissions. It tests pull requests and can build a candidate manually; it does not publish a release. Publication requires review of the exact revision, destination, and artifacts.
