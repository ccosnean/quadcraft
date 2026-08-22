#!/bin/bash
# One-off helper: downloads the bundled font assets from Google Fonts.
set -euo pipefail

DEST="$(cd "$(dirname "$0")/.." && pwd)/assets/fonts"
mkdir -p "$DEST"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"

fetch() {
  family="$1"; weight="$2"; out="$3"
  css=$(curl -sS --max-time 20 -A "$UA" "https://fonts.googleapis.com/css2?family=${family}:wght@${weight}")
  url=$(printf '%s' "$css" | grep -Eo 'https://fonts\.gstatic\.com/[^)]+\.ttf' | head -1)
  if [ -z "$url" ]; then
    echo "failed to resolve $family $weight" >&2
    exit 1
  fi
  curl -sS --max-time 30 -o "$DEST/$out" "$url"
  echo "$out $(wc -c < "$DEST/$out") bytes"
}

fetch "Space+Grotesk" 500 "SpaceGrotesk-Medium.ttf"
fetch "Space+Grotesk" 700 "SpaceGrotesk-Bold.ttf"
fetch "Inter" 400 "Inter-Regular.ttf"
fetch "Inter" 600 "Inter-SemiBold.ttf"
