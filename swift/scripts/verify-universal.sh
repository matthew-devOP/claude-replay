#!/usr/bin/env bash
# Verifies the built .app contains a universal binary (arm64 + x86_64).
# Usage: ./verify-universal.sh /path/to/Claude-MTW-Replay.app
#
# Exit codes:
#   0 — universal (both arm64 and x86_64 present)
#   1 — argument / file error
#   2 — not a universal binary
set -euo pipefail

APP="${1:-}"
if [ -z "$APP" ] || [ ! -d "$APP" ]; then
  echo "Usage: $0 /path/to/Claude-MTW-Replay.app" >&2
  exit 1
fi

# The CFBundleExecutable name may contain spaces (e.g. "Claude MTW Replay").
# Try the conventional name first, fall back to the first executable in MacOS/.
APP_BASENAME="$(basename "$APP" .app)"
EXE="$APP/Contents/MacOS/$APP_BASENAME"
if [ ! -f "$EXE" ]; then
  EXE="$(find "$APP/Contents/MacOS" -type f -perm -u+x | head -1 || true)"
fi
if [ -z "${EXE:-}" ] || [ ! -f "$EXE" ]; then
  echo "ERROR: could not locate executable inside $APP/Contents/MacOS" >&2
  exit 1
fi

echo "Inspecting: $EXE"
ARCHS="$(lipo -info "$EXE" 2>&1 | sed -E 's/.*: //')"
echo "Architectures: $ARCHS"

if echo "$ARCHS" | grep -q "arm64" && echo "$ARCHS" | grep -q "x86_64"; then
  echo "OK — universal binary (arm64 + x86_64)"
  exit 0
else
  echo "FAIL — not a universal binary (got: $ARCHS)" >&2
  exit 2
fi
