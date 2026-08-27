#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <speaches-base-url> <piper-url> <output-dir> [languages]" >&2
  echo "Example: $0 http://127.0.0.1:8102 http://127.0.0.1:8100/v1/audio/speech ./bench-out en,el,ru" >&2
  exit 1
fi

SPEACHES_BASE_URL="${1%/}"
PIPER_URL="$2"
OUTPUT_DIR="$3"
LANGUAGES="${4:-en,el,ru}"

SPEACHES_MODEL="${SPEACHES_TTS_MODEL:-speaches-ai/Kokoro-82M-v1.0-ONNX}"
SPEACHES_VOICE="${SPEACHES_TTS_VOICE:-af_heart}"
PIPER_MODEL="${PIPER_MODEL:-piper-auto}"
PIPER_RESPONSE_FORMAT="${PIPER_RESPONSE_FORMAT:-mp3}"
SPEACHES_API_KEY="${SPEACHES_API_KEY:-not-empty}"
PIPER_API_KEY="${PIPER_API_KEY:-local-dev-key}"
SPEACHES_RESPONSE_FORMAT="${SPEACHES_RESPONSE_FORMAT:-wav}"
export SPEACHES_MODEL SPEACHES_VOICE SPEACHES_RESPONSE_FORMAT PIPER_MODEL PIPER_RESPONSE_FORMAT SPEACHES_API_KEY PIPER_API_KEY

mkdir -p "$OUTPUT_DIR"
RESULTS_FILE="${OUTPUT_DIR}/results.csv"
echo "language,engine,seconds,http_code,bytes,file,text" > "$RESULTS_FILE"

sample_text() {
  case "$1" in
    en) printf '%s' 'Good morning, colleague. We have a short meeting today.' ;;
    el) printf '%s' 'Καλημέρα, συνάδελφε. Έχουμε μια σύντομη συνάντηση σήμερα.' ;;
    ru) printf '%s' 'Доброе утро, коллега. Сегодня у нас короткая встреча.' ;;
    es) printf '%s' 'Buenos días, colega. Hoy tenemos una reunión breve.' ;;
    fr) printf '%s' 'Bonjour, collègue. Nous avons une courte réunion aujourd’hui.' ;;
    de) printf '%s' 'Guten Morgen, Kollege. Wir haben heute eine kurze Besprechung.' ;;
    it) printf '%s' 'Buongiorno, collega. Oggi abbiamo una breve riunione.' ;;
    pt) printf '%s' 'Bom dia, colega. Hoje temos uma reunião curta.' ;;
    ar) printf '%s' 'صباح الخير يا زميلي. لدينا اجتماع قصير اليوم.' ;;
    hi) printf '%s' 'सुप्रभात, सहकर्मी। आज हमारी एक छोटी बैठक है।' ;;
    ja) printf '%s' 'おはようございます、同僚。今日は短い会議があります。' ;;
    ko) printf '%s' '좋은 아침입니다, 동료님. 오늘 짧은 회의가 있습니다.' ;;
    zh) printf '%s' '早上好，同事。今天我们有一个简短的会议。' ;;
    *) printf '%s' "Good morning. This is a short ${1} text-to-speech test." ;;
  esac
}

json_payload() {
  local engine="$1"
  local language="$2"
  local text="$3"
  python3 -c 'import json, os, sys
engine, language, text = sys.argv[1], sys.argv[2], sys.argv[3]
if engine == "speaches":
    payload = {
        "model": os.environ.get("SPEACHES_MODEL", "speaches-ai/Kokoro-82M-v1.0-ONNX"),
        "voice": os.environ.get("SPEACHES_VOICE", "af_heart"),
        "input": text,
        "response_format": os.environ.get("SPEACHES_RESPONSE_FORMAT", "wav"),
    }
else:
    payload = {
        "model": os.environ.get("PIPER_MODEL", "piper-auto"),
        "voice": language,
        "language": language,
        "input": text,
        "response_format": os.environ.get("PIPER_RESPONSE_FORMAT", "wav"),
    }
print(json.dumps(payload, ensure_ascii=False))' "$engine" "$language" "$text"
}

run_engine() {
  local language="$1"
  local engine="$2"
  local url="$3"
  local extension="$4"
  local text="$5"
  local output_file="${OUTPUT_DIR}/${language}-${engine}.${extension}"
  local payload_file
  payload_file="$(mktemp)"
  json_payload "$engine" "$language" "$text" > "$payload_file"

  local metrics
  metrics="$(curl --silent --show-error \
    --output "$output_file" \
    --write-out "%{time_total},%{http_code},%{size_download}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $(if [[ "$engine" == "speaches" ]]; then printf '%s' "$SPEACHES_API_KEY"; else printf '%s' "$PIPER_API_KEY"; fi)" \
    --data "@$payload_file" \
    "$url")"
  rm -f "$payload_file"

  echo "${language},${engine},${metrics},${output_file},\"${text//\"/\"\"}\"" >> "$RESULTS_FILE"
}

IFS=',' read -ra LANG_ARRAY <<< "$LANGUAGES"
for language in "${LANG_ARRAY[@]}"; do
  language="$(echo "$language" | xargs)"
  [[ -z "$language" ]] && continue
  text="$(sample_text "$language")"
  run_engine "$language" "speaches" "${SPEACHES_BASE_URL}/v1/audio/speech" "$SPEACHES_RESPONSE_FORMAT" "$text"
  run_engine "$language" "piper" "$PIPER_URL" "$PIPER_RESPONSE_FORMAT" "$text"
done

echo "Benchmark results saved to ${RESULTS_FILE}"
