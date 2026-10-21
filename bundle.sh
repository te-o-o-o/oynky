#!/bin/sh
# Builds .build/oynky.app: a menu bar app (no Dock icon). The binary inside is also
# the command line tool: `oynky.app/Contents/MacOS/oynky top`.
set -eu
cd "$(dirname "$0")"

VERSION=0.1.0  # the one version: README badges and the release tag must match it
APP=.build/oynky.app

# Universal: one download for Apple Silicon and Intel Macs.
ARCHS="--arch arm64 --arch x86_64"
swift build -c release $ARCHS
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release $ARCHS --show-bin-path)/oynky" "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>io.github.te-o-o-o.oynky</string>
    <key>CFBundleName</key><string>oynky</string>
    <key>CFBundleExecutable</key><string>oynky</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
# Ad-hoc signature: enough for Open at Login and for Apple Silicon to run it.
codesign --force --sign - "$APP"
echo "$APP"
