#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <speaches-base-url> <piper-url> <text-file> <output-dir>" >&2
  echo "Assumes both endpoints are OpenAI-compatible /v1/audio/speech routes." >&2
  exit 1
fi

SPEACHES_BASE_URL="${1%/}"
PIPER_URL="$2"
TEXT_FILE="$3"
OUTPUT_DIR="$4"

SPEACHES_MODEL="${SPEACHES_TTS_MODEL:-speaches-ai/Kokoro-82M-v1.0-ONNX}"
SPEACHES_VOICE="${SPEACHES_TTS_VOICE:-af_heart}"
SPEACHES_RESPONSE_FORMAT="${SPEACHES_RESPONSE_FORMAT:-wav}"
SPEACHES_API_KEY="${SPEACHES_API_KEY:-not-empty}"
PIPER_MODEL="${PIPER_MODEL:-piper-auto}"
PIPER_VOICE="${PIPER_VOICE:-en}"
PIPER_LANGUAGE="${PIPER_LANGUAGE:-en}"
PIPER_RESPONSE_FORMAT="${PIPER_RESPONSE_FORMAT:-mp3}"
PIPER_API_KEY="${PIPER_API_KEY:-local-dev-key}"
export SPEACHES_MODEL SPEACHES_VOICE SPEACHES_RESPONSE_FORMAT PIPER_MODEL PIPER_VOICE PIPER_LANGUAGE PIPER_RESPONSE_FORMAT

mkdir -p "$OUTPUT_DIR"
TEXT="$(cat "$TEXT_FILE")"

SPEACHES_FILE="${OUTPUT_DIR}/speaches.${SPEACHES_RESPONSE_FORMAT}"
PIPER_FILE="${OUTPUT_DIR}/piper.${PIPER_RESPONSE_FORMAT}"

PAYLOAD_FILE="$(mktemp)"
trap 'rm -f "$PAYLOAD_FILE"' EXIT

echo "engine,seconds,http_code,bytes,file" > "${OUTPUT_DIR}/results.csv"

python3 -c 'import json, os, sys
payload = {
    "input": sys.argv[1],
    "model": os.environ["SPEACHES_MODEL"],
    "voice": os.environ["SPEACHES_VOICE"],
    "response_format": os.environ["SPEACHES_RESPONSE_FORMAT"],
}
print(json.dumps(payload, ensure_ascii=False))' "$TEXT" > "$PAYLOAD_FILE"

curl --silent --show-error \
  "$SPEACHES_BASE_URL/v1/audio/speech" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $SPEACHES_API_KEY" \
  --output "$SPEACHES_FILE" \
  --write-out "speaches,%{time_total},%{http_code},%{size_download},${SPEACHES_FILE}\n" \
  --data "@$PAYLOAD_FILE" >> "${OUTPUT_DIR}/results.csv"

python3 -c 'import json, os, sys
payload = {
    "input": sys.argv[1],
    "model": os.environ["PIPER_MODEL"],
    "voice": os.environ["PIPER_VOICE"],
    "language": os.environ["PIPER_LANGUAGE"],
    "response_format": os.environ["PIPER_RESPONSE_FORMAT"],
}
print(json.dumps(payload, ensure_ascii=False))' "$TEXT" > "$PAYLOAD_FILE"

curl --silent --show-error \
  "$PIPER_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $PIPER_API_KEY" \
  --output "$PIPER_FILE" \
  --write-out "piper,%{time_total},%{http_code},%{size_download},${PIPER_FILE}\n" \
  --data "@$PAYLOAD_FILE" >> "${OUTPUT_DIR}/results.csv"

echo "Benchmark results saved to ${OUTPUT_DIR}/results.csv"
