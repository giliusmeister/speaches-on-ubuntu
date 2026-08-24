#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <base-url> <output-file> [text] [model] [voice]" >&2
  exit 1
fi

BASE_URL="${1%/}"
OUTPUT_FILE="$2"
TEXT="${3:-Hello from Speaches text to speech.}"
MODEL="${4:-speaches-ai/Kokoro-82M-v1.0-ONNX}"
VOICE="${5:-af_heart}"

curl --silent --show-error \
  "$BASE_URL/v1/audio/speech" \
  -H "Content-Type: application/json" \
  --output "$OUTPUT_FILE" \
  --data @- <<EOF
{
  "input": "$TEXT",
  "model": "$MODEL",
  "voice": "$VOICE",
  "response_format": "wav"
}
EOF
