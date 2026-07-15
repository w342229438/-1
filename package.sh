#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
OUTPUTS="$ROOT/dist"

zsh "$ROOT/build.sh" doodle
zsh "$ROOT/build.sh" glass

ditto -c -k --keepParent --norsrc --noextattr "$OUTPUTS/QuotaPetWidget-DoodleNote.app" "$OUTPUTS/QuotaPetWidget-DoodleNote.zip"
ditto -c -k --keepParent --norsrc --noextattr "$OUTPUTS/QuotaPetWidget-ClassicGlass.app" "$OUTPUTS/QuotaPetWidget-ClassicGlass.zip"

print "Packaged $OUTPUTS/QuotaPetWidget-DoodleNote.zip"
print "Packaged $OUTPUTS/QuotaPetWidget-ClassicGlass.zip"
