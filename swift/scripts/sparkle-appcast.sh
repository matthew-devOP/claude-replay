#!/usr/bin/env bash
# Generate / refresh appcast.xml for Sparkle-based auto-updates.
#
# Requires Sparkle's CLI tools on PATH:
#   brew install --cask sparkle
# (or download from https://github.com/sparkle-project/Sparkle/releases)
#
# One-time setup: generate the EdDSA signing keypair (kept in keychain):
#   generate_keys
# Put the printed public key into Info.plist under SUPublicEDKey, and the
# Sparkle feed URL under SUFeedURL.
#
# Usage:
#   ./sparkle-appcast.sh /path/to/releases-dir
#
# `generate_appcast` scans the directory for .dmg/.zip files, derives version
# from each bundle's Info.plist, and writes/refreshes appcast.xml in-place.
# Existing entries are preserved.
set -euo pipefail

RELEASES_DIR="${1:-./releases}"
if [ ! -d "$RELEASES_DIR" ]; then
  echo "Usage: $0 /path/to/releases-dir" >&2
  echo "       (directory must already exist and contain at least one signed DMG/ZIP)" >&2
  exit 1
fi

if ! command -v generate_appcast >/dev/null 2>&1; then
  echo "ERROR: 'generate_appcast' not found on PATH." >&2
  echo "Install Sparkle CLI tools: brew install --cask sparkle" >&2
  exit 1
fi

echo "[appcast] scanning $RELEASES_DIR…"
generate_appcast "$RELEASES_DIR"

echo "[appcast] appcast.xml refreshed in $RELEASES_DIR"
ls -la "$RELEASES_DIR/appcast.xml" 2>/dev/null || true
