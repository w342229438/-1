# Codex Quota Widget

A lightweight macOS floating widget for viewing locally available Codex quota information.

![macOS](https://img.shields.io/badge/macOS-13%2B-black)
![Swift](https://img.shields.io/badge/Swift-AppKit-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- Reads hourly and weekly quota windows from the same OpenAI usage service used by Codex, with the local Codex RPC and session JSONL files as fallbacks.
- Includes a compact hand-drawn note style and a classic glass style.
- Shows reset time, remaining quota, and automatically refreshed usage-limit reset credits.
- Click any quota icon to force an immediate refresh, including while a background refresh is already running.
- Uses the existing local Codex sign-in only for quota requests and does not send telemetry.
- Runs as a floating macOS accessory app with a menu-bar menu for settings and exit.

## Privacy and Data

When automatic sync is enabled, the widget reads the access token from `~/.codex/auth.json` and sends it only to `https://chatgpt.com/backend-api/wham/usage` over HTTPS. The token is kept in memory for the request and is never logged, copied, or stored by the widget.

If the OpenAI usage request fails, the widget asks the locally installed Codex CLI for `account/rateLimits/read`. It also reads `~/.codex/sessions/**/*.jsonl` on the same Mac only as a final fallback for locally recorded quota-window data. Session files are never uploaded by this project. Windows are identified by their reported duration instead of their `primary` or `secondary` position, and a missing 5-hour window is shown as waiting rather than being replaced with the weekly value.

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

The OpenAI usage endpoint and local Codex data formats are not documented as stable public integration APIs. They can change, so parsing may need maintenance in the future. If the service does not return a 5-hour window for the current account, the widget cannot reconstruct that value and will show it as waiting for sync.

## Contributing

Bug reports and pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting changes.

Please review [SECURITY.md](SECURITY.md) before reporting a vulnerability and [NOTICE.md](NOTICE.md) for visual-design references.

## License

Released under the [MIT License](LICENSE).
