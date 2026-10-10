# Security and file-safety reports

Unpile is still a local beta. There is no public release or configured private reporting channel yet. Enabling a private channel is a publication requirement.

After the repository is published, use **Security → Report a vulnerability** if private vulnerability reporting is enabled. If that control is unavailable, request a private contact without publishing the technical details. Do not post filenames, file contents, bookmarks, review-state JSON, screenshots of real folders, or full logs in a public issue.

Include only the affected version, macOS/architecture, a brief impact description, and reproduction with synthetic files. State whether anything moved, remained in place, or has an uncertain result. Redact paths and account identifiers.

If a file-handling failure occurs, stop using the affected build and inspect the original folder and Finder's Trash. Do not empty Trash. Unpile does not automatically restore files or infer success from a missing source path.

Safety boundaries: one explicitly selected local folder; ordinary files at its top level; no recursion through links; no accounts, servers, or analytics; decision-only Undo; repeated metadata checks and a durable transfer journal. Metadata and path-based operations cannot rule out every race with another process. Supported preview types are limited; HTML/SVG are excluded.

No response-time guarantee is made until a maintainer and private channel are configured. Confirmed file-loss risks take priority over feature work and require withdrawal of an affected public binary.
