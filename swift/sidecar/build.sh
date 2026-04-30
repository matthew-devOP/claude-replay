#!/usr/bin/env bash
# Build & deploy the Node sidecar into the Swift app's Resources/.
#
# Idempotent: safe to re-run. Should be invoked from `swift/scripts/build-dmg.sh`
# before xcodebuild so the Resources directory is up to date.
set -euo pipefail

SIDECAR_DIR="$(cd "$(dirname "$0")" && pwd)"
# Folder reference target. Living outside Resources/ so xcodegen doesn't
# fan it out as individual files (zod's package contains duplicate basenames
# that would clash if flattened).
APP_RES_DIR="$SIDECAR_DIR/../Claude-MTW-Replay/Sidecar"

echo "[sidecar] installing production dependencies…"
cd "$SIDECAR_DIR"
npm install --omit=dev --no-audit --no-fund --silent

echo "[sidecar] copying into $APP_RES_DIR"
rm -rf "$APP_RES_DIR"
mkdir -p "$APP_RES_DIR"
cp -R sidecar.js package.json node_modules "$APP_RES_DIR/"

echo "[sidecar] done. Bundle size:"
du -sh "$APP_RES_DIR"
