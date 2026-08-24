#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${SCRIPT_DIR}/../../.env" ]]; then
  set -a
  source "${SCRIPT_DIR}/../../.env"
  set +a
fi

if [[ ! -d "${SCRIPT_DIR}/.venv" ]]; then
  python3 -m venv "${SCRIPT_DIR}/.venv"
fi

source "${SCRIPT_DIR}/.venv/bin/activate"
pip install --upgrade pip
pip install -r "${SCRIPT_DIR}/requirements.txt"

exec uvicorn app:app \
  --app-dir "${SCRIPT_DIR}" \
  --host "${OPENLINGO_STT_ADAPTER_HOST:-0.0.0.0}" \
  --port "${OPENLINGO_STT_ADAPTER_PORT:-8010}"
