#!/usr/bin/env bash
set -euo pipefail

OS_NAME="$(uname -s)"

echo "== Platform =="
echo "$OS_NAME"

echo
echo "== Host Ollama =="
if curl -fsS http://127.0.0.1:11434/api/tags | head; then
  echo "[ok] Host Ollama is reachable."
else
  echo "[ng] Host Ollama is not reachable."
  if [ "$OS_NAME" = "Darwin" ]; then
    echo "    macOS hint:"
    echo "      launchctl setenv OLLAMA_HOST \"0.0.0.0:11434\""
    echo "      then quit and relaunch the Ollama app."
  else
    echo "    Linux hint:"
    echo "      sudo systemctl edit ollama   # add OLLAMA_HOST=0.0.0.0:11434"
    echo "      sudo systemctl restart ollama"
  fi
fi

echo
echo "== Docker services =="
docker compose ps

echo
echo "== WebUI config =="
docker exec hermes-webui bash -lc 'sed -n "1,40p" /home/hermeswebui/.hermes/config.yaml' || true

echo
echo "== WebUI -> Ollama =="
docker exec hermes-webui bash -lc 'curl -s http://host.docker.internal:11434/v1/models | head' || true

echo
echo "== Agent -> Ollama =="
docker exec hermes-agent sh -lc 'python3 - <<PY
import urllib.request
print(urllib.request.urlopen("http://host.docker.internal:11434/v1/models", timeout=5).read().decode()[:500])
PY' || true

echo
echo "== Recent WebUI logs =="
docker compose logs --tail=80 hermes-webui
