#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
MODULE_CACHE="$ROOT/.module-cache"
OUTPUTS="$ROOT/dist"
STYLE="${1:-doodle}"

case "$STYLE" in
  doodle)
    APP="$OUTPUTS/QuotaPetWidget-DoodleNote.app"
    DISPLAY_NAME="Quota Pet Widget - Doodle"
    BUNDLE_ID="local.codex.quota-pet-widget.doodle"
    SWIFT_FLAGS=()
    ;;
  glass)
    APP="$OUTPUTS/QuotaPetWidget-ClassicGlass.app"
    DISPLAY_NAME="Quota Pet Widget - Classic Glass"
    BUNDLE_ID="local.codex.quota-pet-widget.classic-glass"
    SWIFT_FLAGS=(-D GLASS_STYLE)
    ;;
  *)
    print -u2 "Usage: $0 [doodle|glass]"
    exit 1
    ;;
esac

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$MODULE_CACHE"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
plutil -replace CFBundleDisplayName -string "$DISPLAY_NAME" "$APP/Contents/Info.plist"
plutil -replace CFBundleName -string "$DISPLAY_NAME" "$APP/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$APP/Contents/Info.plist"
swiftc "$ROOT/QuotaPetWidget.swift" -parse-as-library -module-cache-path "$MODULE_CACHE" "${SWIFT_FLAGS[@]}" -framework Cocoa -o "$APP/Contents/MacOS/QuotaPetWidget"
echo "Built $APP"
