#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/speaches-on-ubuntu}"
SPEACHES_DIR="${SPEACHES_DIR:-/opt/speaches}"
CONFIGURE_NGINX="${CONFIGURE_NGINX:-snippet}"

sudo apt-get update
sudo apt-get install -y python3 python3-venv ffmpeg curl git nginx gettext-base

if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

sudo mkdir -p "$APP_DIR"
sudo rsync -a --delete --exclude ".git" ./ "$APP_DIR/"
sudo find "$APP_DIR/scripts" -maxdepth 1 -type f -name "*.sh" -exec chmod 755 {} \;
sudo find "$APP_DIR/services" -mindepth 2 -maxdepth 2 -type f -name "run.sh" -exec chmod 755 {} \;

if [[ ! -f "$APP_DIR/.env" ]]; then
  sudo cp "$APP_DIR/.env.example" "$APP_DIR/.env"
fi

bash "$APP_DIR/scripts/install-ubuntu24-native.sh" "$SPEACHES_DIR"

sudo cp "$APP_DIR/deploy/speaches.service" /etc/systemd/system/speaches.service
sudo cp "$APP_DIR/deploy/openlingo-stt-adapter.service" /etc/systemd/system/openlingo-stt-adapter.service
sudo systemctl daemon-reload
sudo systemctl enable speaches openlingo-stt-adapter
sudo systemctl restart speaches openlingo-stt-adapter

SPEACHES_PORT_VALUE="$(sudo awk -F= '/^SPEACHES_PORT=/{print $2}' "$APP_DIR/.env" | tail -n 1)"
ADAPTER_PORT_VALUE="$(sudo awk -F= '/^OPENLINGO_STT_ADAPTER_PORT=/{print $2}' "$APP_DIR/.env" | tail -n 1)"
FALLBACK_PORT_VALUE="$(sudo awk -F= '/^FASTER_WHISPER_PORT=/{print $2}' "$APP_DIR/.env" | tail -n 1)"
NGINX_API_PORT_VALUE="$(sudo awk -F= '/^NGINX_API_PORT=/{print $2}' "$APP_DIR/.env" | tail -n 1)"
LAN_HOST_VALUE="$(sudo awk -F= '/^LAN_HOST=/{print $2}' "$APP_DIR/.env" | tail -n 1)"

sudo mkdir -p /etc/nginx/snippets
sed \
  -e "s/__SPEACHES_PORT__/${SPEACHES_PORT_VALUE:-8000}/g" \
  -e "s/__ADAPTER_PORT__/${ADAPTER_PORT_VALUE:-8010}/g" \
  -e "s/__FALLBACK_PORT__/${FALLBACK_PORT_VALUE:-8020}/g" \
  "$APP_DIR/deploy/nginx-speaches-api.locations.conf" \
  | sudo tee /etc/nginx/snippets/speaches-api.locations.conf >/dev/null

if [[ "$CONFIGURE_NGINX" == "site" ]]; then
  sed \
    -e "s/listen 18081;/listen ${NGINX_API_PORT_VALUE:-18081};/g" \
    -e "s/server_name 192.168.11.11;/server_name ${LAN_HOST_VALUE:-192.168.11.11};/g" \
    "$APP_DIR/deploy/nginx-speaches-api.site.conf" \
    | sudo tee /etc/nginx/sites-available/speaches-api >/dev/null
  sudo ln -sf /etc/nginx/sites-available/speaches-api /etc/nginx/sites-enabled/speaches-api
  sudo nginx -t
  sudo systemctl reload nginx
  echo "Ready through nginx: http://${LAN_HOST_VALUE:-192.168.11.11}:${NGINX_API_PORT_VALUE:-18081}/v1/audio/transcriptions"
else
  echo "Nginx snippet installed: /etc/nginx/snippets/speaches-api.locations.conf"
  echo "Include it in an existing server block, then run: sudo nginx -t && sudo systemctl reload nginx"
fi

echo "Local Speaches ready: http://127.0.0.1:${SPEACHES_PORT_VALUE:-8000}/v1/audio/transcriptions"
echo "Local adapter ready: http://127.0.0.1:${ADAPTER_PORT_VALUE:-8010}/api/stt"
