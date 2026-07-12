# Codex Quota Widget

A lightweight macOS floating widget for viewing locally available Codex quota information.

![macOS](https://img.shields.io/badge/macOS-13%2B-black)
![Swift](https://img.shields.io/badge/Swift-AppKit-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- Reads the locally available hourly and weekly quota windows from Codex session JSONL files.
- Includes a compact hand-drawn note style and a classic glass style.
- Shows reset time, remaining quota, and a manually maintained reset-credit summary.
- Stays local: no network requests, account credentials, or telemetry.
- Runs as a floating macOS accessory app with a menu-bar menu for settings and exit.

## Privacy and Data

The widget reads `~/.codex/sessions/**/*.jsonl` on the same Mac to obtain locally recorded quota-window data. Those files are never uploaded by this project.

Codex does not currently expose reset-credit inventory and expiration data in the local fields read by this widget. The reset-credit count and two expiration dates are therefore configured manually in the widget's Settings window.

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

The app is unsigned. macOS may require you to open it from Finder with Control-click > Open on first launch.

## Project Files

- `QuotaPetWidget.swift` - AppKit application and local quota reader
- `Info.plist` - macOS application metadata
- `build.sh` - Builds either visual style
- `package.sh` - Builds and packages both styles

## Limitations

This project reads locally recorded Codex session data rather than an official public quota API. The underlying session format can change, so parsing may need maintenance in the future.

## Contributing

Bug reports and pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting changes.

Please review [SECURITY.md](SECURITY.md) before reporting a vulnerability and [NOTICE.md](NOTICE.md) for visual-design references.

## License

Released under the [MIT License](LICENSE).
