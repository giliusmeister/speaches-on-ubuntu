#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <adapter-base-url> <audio-file>" >&2
  exit 1
fi

BASE_URL="${1%/}"
AUDIO_FILE="$2"

curl --silent --show-error \
  "$BASE_URL/api/stt" \
  -F "file=@${AUDIO_FILE}"
