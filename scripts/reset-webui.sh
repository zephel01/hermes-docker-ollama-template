#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "Stopping containers..."
docker compose down

echo "Backing up WebUI state..."

if [ -d "$HOME/.hermes/webui" ]; then
  mv "$HOME/.hermes/webui" "$HOME/.hermes/webui.bak.$(date +%Y%m%d-%H%M%S)"
fi

if [ -d "$HOME/.hermes/webui-mvp" ]; then
  mv "$HOME/.hermes/webui-mvp" "$HOME/.hermes/webui-mvp.bak.$(date +%Y%m%d-%H%M%S)"
fi

echo "Starting containers..."
docker compose up -d --build

echo "Done."
echo "Open: http://127.0.0.1:8787"
