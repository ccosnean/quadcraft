#!/usr/bin/env bash
# Captures store screenshots for every locale x device target listed in
# store/devices.yaml, via test/store_screenshots_test.dart. No simulator or
# emulator involved — screens are rendered directly with `flutter test`
# (RenderRepaintBoundary.toImage at the exact pixel size store/devices.yaml
# asks for), so this is fast and doesn't need Xcode/Android tooling booted.
#
# Output lands in store/screenshots/<locale>/<folder>/*.png — feed it into
# ios/fastlane and android/fastlane with:
#   dart run tool/store/sync_store_content.dart
#
# Usage:
#   tool/store/capture_screenshots.sh
#
# Known toolchain quirk (see test/store_screenshots_test.dart's header):
# `flutter test` can take a very long time to exit cleanly after this
# specific test finishes — a software-rasterizer teardown issue, unrelated
# to whether the screenshots came out correctly. Rather than wait on that,
# this script polls the test's own log for the SCREENSHOTS_COMPLETE marker
# printed right after the last file is written, then kills the process.
set -uo pipefail
cd "$(dirname "$0")/../.."

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

echo "==> flutter test test/store_screenshots_test.dart"
flutter test test/store_screenshots_test.dart > "$LOG" 2>&1 &
PID=$!

# Generous ceiling: 13 locales x 3 devices x 3 screens is real rendering
# work, just not simulator-boot-and-build work. Adjust if you add locales
# or device targets in store/devices.yaml.
CEILING=900
DEADLINE=$((SECONDS + CEILING))
STATUS="timeout"
while [ "$SECONDS" -lt "$DEADLINE" ]; do
  if grep -q "SCREENSHOTS_COMPLETE" "$LOG" 2>/dev/null; then
    STATUS="complete"
    break
  fi
  if ! kill -0 "$PID" 2>/dev/null; then
    STATUS="exited"
    break
  fi
  sleep 2
done

if kill -0 "$PID" 2>/dev/null; then
  kill "$PID" 2>/dev/null
  pkill -P "$PID" 2>/dev/null
  pkill -f "flutter_tester.*store_screenshots_test" 2>/dev/null
fi

case "$STATUS" in
  complete)
    echo "Done. Screenshots are under store/screenshots/. Run:"
    echo "  dart run tool/store/sync_store_content.dart"
    echo "to fan them out into ios/fastlane and android/fastlane."
    ;;
  exited)
    echo "flutter test exited before finishing — showing its output:" >&2
    cat "$LOG" >&2
    exit 1
    ;;
  timeout)
    echo "error: no SCREENSHOTS_COMPLETE marker after ${CEILING}s — something hung mid-capture. Log:" >&2
    tail -80 "$LOG" >&2
    exit 1
    ;;
esac
