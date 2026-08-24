#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <base-url>" >&2
  exit 1
fi

BASE_URL="${1%/}"

curl --silent --show-error --fail "${BASE_URL}/health"
