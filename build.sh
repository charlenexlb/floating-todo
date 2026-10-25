#!/bin/zsh
# Builds FloatingTodo.app from main.swift.
set -euo pipefail

cd "$(dirname "$0")"

APP="FloatingTodo.app"
TARGET="$(uname -m)-apple-macosx13.0"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -target "$TARGET" \
    main.swift -o "$APP/Contents/MacOS/FloatingTodo"

# App icon: draw the PNGs, then pack them into an .icns file.
swiftc -target "$TARGET" make_icon.swift -o "$WORK/make_icon"
"$WORK/make_icon" "$WORK/AppIcon.iconset"
iconutil -c icns "$WORK/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "Built $APP — run with: open $APP"
