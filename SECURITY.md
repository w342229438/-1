# Security Policy

## Supported versions

The latest version on the `main` branch is supported.

## Reporting a vulnerability

Please do not publish raw Codex session files or account-related information in a public issue.

Open a minimal issue that describes the behavior and macOS version, or contact the repository owner privately through GitHub. Include only redacted logs or screenshots.

## Local data handling

For automatic quota sync, the widget reads the access token from `~/.codex/auth.json` and sends it only to `https://chatgpt.com/backend-api/wham/usage` over HTTPS. The token is kept in memory and is not logged or stored by the widget. Local session files under `~/.codex/sessions` are read only as a fallback and are never transmitted. Contributors must not add authentication files, session files, build artifacts, or personal screenshots to commits.
