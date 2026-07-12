# Security Policy

## Supported versions

The latest version on the `main` branch is supported.

## Reporting a vulnerability

Please do not publish raw Codex session files or account-related information in a public issue.

Open a minimal issue that describes the behavior and macOS version, or contact the repository owner privately through GitHub. Include only redacted logs or screenshots.

## Local data handling

The widget reads local files under `~/.codex/sessions` at runtime. It does not transmit those files or make network requests. Contributors must not add session files, build artifacts, or personal screenshots to commits.
