#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <speaches-install-dir>" >&2
  exit 1
fi

SPEACHES_DIR="$1"

sudo apt update
sudo apt install -y python3 python3-venv ffmpeg curl git

if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

if [[ ! -d "$SPEACHES_DIR/.git" ]]; then
  git clone https://github.com/speaches-ai/speaches.git "$SPEACHES_DIR"
fi

cd "$SPEACHES_DIR"
uv python install
uv venv
source .venv/bin/activate
uv sync

echo
echo "Speaches native install is prepared in: $SPEACHES_DIR"
echo "Start manually with:"
echo "  source .venv/bin/activate && uvicorn --factory --host 0.0.0.0 --port 8000 speaches.main:create_app"
