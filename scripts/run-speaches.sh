#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="/opt/speaches-on-ubuntu"
SPEACHES_DIR="/opt/speaches"

if [[ -f "${CONFIG_DIR}/.env" ]]; then
  set -a
  source "${CONFIG_DIR}/.env"
  set +a
fi

exec "${SPEACHES_DIR}/.venv/bin/uvicorn" \
  --factory \
  --host "${SPEACHES_HOST:-0.0.0.0}" \
  --port "${SPEACHES_PORT:-8101}" \
  speaches.main:create_app
