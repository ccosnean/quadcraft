#!/usr/bin/env bash
# The one publish command: regenerates ios/fastlane and android/fastlane from
# store/ (so a stale sync never gets uploaded by accident), then runs the
# matching fastlane lane(s). Requires the one-time setup in store/README.md
# (app records created, API credentials in ios/fastlane/.env and
# android/fastlane/.env, a first build already on each console).
#
# Usage:
#   tool/store/publish.sh <ios|android|all> <metadata|screenshots|metadata_and_screenshots>
#
# Examples:
#   tool/store/publish.sh android metadata
#   tool/store/publish.sh all metadata_and_screenshots
set -euo pipefail
cd "$(dirname "$0")/../.."

PLATFORM="${1:-}"
LANE="${2:-}"

usage() {
  echo "Usage: tool/store/publish.sh <ios|android|all> <metadata|screenshots|metadata_and_screenshots>" >&2
  exit 64
}

case "$PLATFORM" in
  ios|android|all) ;;
  *) usage ;;
esac

case "$LANE" in
  metadata|screenshots|metadata_and_screenshots) ;;
  *) usage ;;
esac

echo "==> Syncing store/ content into ios/fastlane and android/fastlane"
dart run tool/store/sync_store_content.dart

run_platform() {
  local platform="$1"
  if [ ! -f "$platform/fastlane/.env" ]; then
    echo "error: $platform/fastlane/.env is missing — copy $platform/fastlane/.env.example" \
         "and fill in real credentials first. See store/README.md." >&2
    exit 1
  fi
  echo "==> fastlane $platform $LANE"
  (cd "$platform" && fastlane "$LANE")
}

if [ "$PLATFORM" = "all" ]; then
  run_platform ios
  run_platform android
else
  run_platform "$PLATFORM"
fi
