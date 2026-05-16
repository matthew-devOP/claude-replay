#!/usr/bin/env bash
# Notarize a built DMG via xcrun notarytool, then staple the ticket.
#
# Requires Apple Developer Program enrollment ($99/yr) and an app-specific
# password (or a stored keychain profile via `notarytool store-credentials`).
#
# Configure these env vars before running:
#   APPLE_ID=<your-apple-id@example.com>
#   APPLE_PASSWORD=<app-specific-password>     # or: @keychain:NOTARIZE
#   APPLE_TEAM_ID=<TEAMID>
#
# Alternative: use a stored keychain profile (recommended for CI):
#   xcrun notarytool store-credentials "NOTARIZE" \
#     --apple-id <you> --team-id <TEAM> --password <app-specific-pw>
# Then export NOTARY_PROFILE=NOTARIZE instead of APPLE_ID/PASSWORD/TEAM_ID.
#
# Usage:
#   ./notarize.sh /path/to/Claude-MTW-Replay-X.Y.Z.dmg
set -euo pipefail

DMG="${1:-}"
if [ -z "$DMG" ] || [ ! -f "$DMG" ]; then
  echo "Usage: $0 /path/to/Claude-MTW-Replay-X.Y.Z.dmg" >&2
  exit 1
fi

echo "[notarize] target: $DMG"

if [ -n "${NOTARY_PROFILE:-}" ]; then
  echo "[notarize] using keychain profile: $NOTARY_PROFILE"
  xcrun notarytool submit "$DMG" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
else
  : "${APPLE_ID:?APPLE_ID is required (or set NOTARY_PROFILE)}"
  : "${APPLE_PASSWORD:?APPLE_PASSWORD is required (or set NOTARY_PROFILE)}"
  : "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required (or set NOTARY_PROFILE)}"
  echo "[notarize] using inline credentials for $APPLE_ID (team $APPLE_TEAM_ID)"
  xcrun notarytool submit "$DMG" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait
fi

echo "[notarize] stapling ticket…"
xcrun stapler staple "$DMG"

echo "[notarize] validating staple…"
xcrun stapler validate "$DMG"

echo "[notarize] done."
