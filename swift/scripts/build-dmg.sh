#!/usr/bin/env bash
# Build a versioned DMG for the Claude MTW Replay app.
# Idempotent: re-running with the same package.json version overwrites
# only that version's DMG; older DMGs in swift/dist/ are kept (per the
# user's per-version preservation request).
#
# Pipeline:
#   1. read version from package.json
#   2. build Node sidecar (swift/sidecar/build.sh) → Claude-MTW-Replay/Sidecar/
#   3. xcodegen generate
#   4. xcodebuild Release (universal arm64+x86_64)
#   5. stage app + Applications symlink in a tmp dir
#   6. hdiutil create swift/dist/Claude-MTW-Replay-<ver>.dmg
#   7. mount/detach smoke test
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SWIFT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$SWIFT_DIR/.." && pwd)"
DIST_DIR="$SWIFT_DIR/dist"

VERSION="$(node -p "require('$REPO_DIR/package.json').version")"
DMG_NAME="Claude-MTW-Replay-$VERSION.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

echo "[dmg] target version: $VERSION"
echo "[dmg] output:         $DMG_PATH"

# 1. Sidecar bundle
echo "[dmg] building sidecar…"
"$SWIFT_DIR/sidecar/build.sh"

# 2. Xcode project
echo "[dmg] regenerating xcodeproj…"
cd "$SWIFT_DIR"
xcodegen generate >/dev/null

# 3. Build the .app
echo "[dmg] building Release (universal)…"
xcodebuild \
  -project Claude-MTW-Replay.xcodeproj \
  -scheme Claude-MTW-Replay \
  -configuration Release \
  -derivedDataPath build \
  -destination 'platform=macOS' \
  build \
  -quiet \
  | tail -5
APP="$SWIFT_DIR/build/Build/Products/Release/Claude MTW Replay.app"
[ -d "$APP" ] || { echo "[dmg] build did not produce $APP" >&2; exit 1; }

# 4. Stage + DMG
mkdir -p "$DIST_DIR"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "[dmg] hdiutil create…"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "Claude MTW Replay $VERSION" \
  -srcfolder "$STAGE" \
  -ov -format UDZO -fs HFS+ \
  "$DMG_PATH" \
  | tail -2
rm -rf "$STAGE"

# 5. Smoke test
echo "[dmg] smoke-mounting…"
hdiutil attach -readonly -nobrowse "$DMG_PATH" >/dev/null
VOLUME="/Volumes/Claude MTW Replay $VERSION"
ls "$VOLUME" >/dev/null
hdiutil detach "$VOLUME" >/dev/null

ls -la "$DMG_PATH"
echo "[dmg] done."
