# Security

Never attach `auth.json`, credentials, private session logs, raw account responses or access-bearing URLs to issues. Report a suspected vulnerability using GitHub's private vulnerability reporting when available, or open an issue that describes the impact without secrets or exploit data.

Codex Pace has no account service or telemetry endpoint. It invokes the separately installed CodexBar CLI with the OAuth source to read the current user's Codex quota. Builds use Apple's system frameworks; no third-party Swift package is fetched. GitHub Actions tests use synthetic data and do not access provider accounts.

Public binaries currently have ad-hoc signatures and are not Apple-notarized. Checksums help check download integrity; they do not replace a Developer ID signature. The installer does not remove quarantine or change system security settings.
