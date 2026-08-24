#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${ROOT_DIR}/.env" ]]; then
  set -a
  source "${ROOT_DIR}/.env"
  set +a
fi

OUTPUT_DIR="${1:-${ROOT_DIR}/.generated-nginx}"
mkdir -p "${OUTPUT_DIR}"

envsubst '${APP_HOST} ${APP_PORT} ${NGINX_HTTP_PORT} ${NGINX_API_PORT} ${NGINX_SERVER_NAME} ${SPEACHES_PORT} ${OPENLINGO_STT_ADAPTER_PORT} ${FASTER_WHISPER_PORT}' \
  < "${ROOT_DIR}/nginx/app.conf.template" \
  > "${OUTPUT_DIR}/app.conf"

envsubst '${NGINX_API_PORT} ${NGINX_SERVER_NAME} ${SPEACHES_PORT} ${OPENLINGO_STT_ADAPTER_PORT} ${FASTER_WHISPER_PORT}' \
  < "${ROOT_DIR}/nginx/api.conf.template" \
  > "${OUTPUT_DIR}/api.conf"

echo "Rendered nginx configs into ${OUTPUT_DIR}"
