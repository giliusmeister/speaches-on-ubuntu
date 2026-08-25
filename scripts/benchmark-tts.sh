#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <speaches-base-url> <piper-url> <text-file> <output-dir>" >&2
  echo "Assumes Piper endpoint is OpenAI-compatible /v1/audio/speech." >&2
  exit 1
fi

SPEACHES_BASE_URL="${1%/}"
PIPER_URL="$2"
TEXT_FILE="$3"
OUTPUT_DIR="$4"

SPEACHES_MODEL="${SPEACHES_TTS_MODEL:-speaches-ai/Kokoro-82M-v1.0-ONNX}"
SPEACHES_VOICE="${SPEACHES_TTS_VOICE:-af_heart}"

mkdir -p "$OUTPUT_DIR"
TEXT="$(cat "$TEXT_FILE")"

echo "engine,seconds,bytes,file" > "${OUTPUT_DIR}/results.csv"

curl --silent --show-error \
  "$SPEACHES_BASE_URL/v1/audio/speech" \
  -H "Content-Type: application/json" \
  --output "${OUTPUT_DIR}/speaches.wav" \
  --write-out "speaches,%{time_total},%{size_download},${OUTPUT_DIR}/speaches.wav\n" \
  --data @- <<EOF >> "${OUTPUT_DIR}/results.csv"
{
  "input": "$TEXT",
  "model": "$SPEACHES_MODEL",
  "voice": "$SPEACHES_VOICE",
  "response_format": "wav"
}
EOF

curl --silent --show-error \
  "$PIPER_URL" \
  -H "Content-Type: application/json" \
  --output "${OUTPUT_DIR}/piper.wav" \
  --write-out "piper,%{time_total},%{size_download},${OUTPUT_DIR}/piper.wav\n" \
  --data @- <<EOF >> "${OUTPUT_DIR}/results.csv"
{
  "model": "piper-auto",
  "voice": "en",
  "language": "en",
  "input": "$TEXT",
  "response_format": "wav"
}
EOF

echo "Benchmark results saved to ${OUTPUT_DIR}/results.csv"
