# Codex Quota Widget

A lightweight macOS floating widget for viewing locally available Codex quota information.

![macOS](https://img.shields.io/badge/macOS-13%2B-black)
![Swift](https://img.shields.io/badge/Swift-AppKit-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- Reads the locally available hourly and weekly quota windows from Codex session JSONL files.
- Includes a compact hand-drawn note style and a classic glass style.
- Shows reset time, remaining quota, and automatically refreshed usage-limit reset credits.
- Keeps authentication inside the installed Codex CLI; the widget does not read credentials or send telemetry.
- Runs as a floating macOS accessory app with a menu-bar menu for settings and exit.

## Privacy and Data

The widget reads `~/.codex/sessions/**/*.jsonl` on the same Mac to obtain locally recorded quota-window data. Those files are never uploaded by this project.

When automatic sync is enabled, the widget asks the locally installed Codex CLI for `account/rateLimits/read` once per minute. This provides the usage-limit reset count and available expiration dates without reading or storing account credentials. If the CLI or endpoint is unavailable, the reset count and dates configured in the widget's Settings window remain as the fallback.

Do not commit your local Codex session files, screenshots containing account information, or built application archives.

## Requirements

- macOS 13 or later
- Xcode Command Line Tools with `swiftc`

## Build

```zsh
zsh build.sh doodle
```

The built app is written to `dist/QuotaPetWidget-DoodleNote.app`.

Build the classic glass variant:

```zsh
zsh build.sh glass
```

Package both variants into ZIP archives:

```zsh
zsh package.sh
```

## Run

```zsh
open dist/QuotaPetWidget-DoodleNote.app
```

The build script applies a local ad-hoc signature, but the app is not notarized with an Apple Developer ID. On first launch, macOS may report that the developer cannot be verified. If that happens, open Finder, Control-click (or right-click) the app, choose **Open**, then confirm **Open** once more.

## Project Files

- `QuotaPetWidget.swift` - AppKit application and local quota reader
- `Info.plist` - macOS application metadata
- `assets/AppIcon.png` - Transparent hand-drawn app icon source
- `assets/AppIcon.icns` - Packaged macOS app icon
- `build.sh` - Builds either visual style
- `package.sh` - Builds and packages both styles

## Limitations

This project reads locally recorded Codex session data rather than an official public quota API. The underlying session format can change, so parsing may need maintenance in the future.

## Contributing

Bug reports and pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting changes.

Please review [SECURITY.md](SECURITY.md) before reporting a vulnerability and [NOTICE.md](NOTICE.md) for visual-design references.

## License

Released under the [MIT License](LICENSE).
