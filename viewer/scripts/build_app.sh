#!/usr/bin/env bash
# Build MdReader.app (macOS companion Markdown viewer) into viewer/dist/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/MdReader.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"
SRC="$ROOT/Sources/MdReaderViewer/main.swift"

echo "==> building MdReader.app"
rm -rf "$APP"
mkdir -p "$MACOS" "$RES"

# Compile
swiftc -O \
  -framework AppKit \
  -framework WebKit \
  -o "$MACOS/MdReader" \
  "$SRC"

# Resources (offline markdown stack)
cp "$ROOT/Resources/marked.min.js" "$RES/"
cp "$ROOT/Resources/github-markdown.min.css" "$RES/"
cp "$ROOT/Resources/highlight.min.js" "$RES/"
cp "$ROOT/Resources/highlight-github-dark.min.css" "$RES/"

# Info.plist — URL scheme md-reader://
cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>MdReader</string>
  <key>CFBundleIdentifier</key>
  <string>com.yanauto.mdreader</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>MdReader</string>
  <key>CFBundleDisplayName</key>
  <string>MdReader</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.3.0</string>
  <key>CFBundleVersion</key>
  <string>3</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>Markdown</string>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>LSHandlerRank</key>
      <string>Owner</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>net.daringfireball.markdown</string>
        <string>public.plain-text</string>
      </array>
      <key>CFBundleTypeExtensions</key>
      <array>
        <string>md</string>
        <string>markdown</string>
        <string>txt</string>
        <string>mdc</string>
      </array>
    </dict>
  </array>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key>
      <string>com.yanauto.mdreader.open</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>md-reader</string>
      </array>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
    </dict>
  </array>
</dict>
</plist>
PLIST

# PkgInfo
echo -n "APPL????" > "$CONTENTS/PkgInfo"

# Install / register for URL scheme: copy to ~/Applications if requested
if [[ "${1:-}" == "--install" ]]; then
  DEST="${HOME}/Applications/MdReader.app"
  mkdir -p "${HOME}/Applications"
  rm -rf "$DEST"
  cp -R "$APP" "$DEST"
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST"
  echo "==> installed: $DEST (URL scheme md-reader:// registered)"
else
  # Register dist app so scheme works in dev
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" || true
  echo "==> built: $APP"
  echo "    install permanently: $0 --install"
fi
