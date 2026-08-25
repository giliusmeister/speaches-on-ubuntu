#!/usr/bin/env bash
set -euo pipefail

SPEACHES_DIR="${1:-/opt/speaches}"
MODEL_ID="${2:-Systran/faster-distil-whisper-small.en}"
BASE_URL="${3:-http://127.0.0.1:8101}"

cd "${SPEACHES_DIR}"
source .venv/bin/activate

export SPEACHES_BASE_URL="${BASE_URL}"

uvx speaches-cli registry ls --task automatic-speech-recognition > /dev/null
uvx speaches-cli model download "${MODEL_ID}"
uvx speaches-cli model ls --task automatic-speech-recognition
