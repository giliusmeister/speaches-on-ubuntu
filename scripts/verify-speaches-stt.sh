#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <base-url> <audio-file> [model]" >&2
  exit 1
fi

BASE_URL="${1%/}"
AUDIO_FILE="$2"
MODEL="${3:-Systran/faster-distil-whisper-small.en}"

curl --silent --show-error \
  "$BASE_URL/v1/audio/transcriptions" \
  -F "file=@${AUDIO_FILE}" \
  -F "model=${MODEL}"
