#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
OLLAMA_DOCKER=0

usage() {
  cat <<USAGE
Usage: $0 [OPTIONS]

Options:
  --ollama-docker   Configure for "Ollama in Docker" mode.
                    Use this if you want Ollama to run as a container too.
                    Recommended only on Linux. Not recommended on macOS
                    (Docker Desktop cannot pass Apple Silicon GPU through).
  -h, --help        Show this help.

Default mode runs Ollama on the host. This is the right choice for macOS,
and the simpler choice for Linux unless you specifically want everything
inside Docker.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --ollama-docker) OLLAMA_DOCKER=1 ;;
    -h|--help)       usage; exit 0 ;;
    *)
      echo "ERROR: unknown option: $arg"
      usage
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# OS detection
# ---------------------------------------------------------------------------
OS_NAME="$(uname -s)"
case "$OS_NAME" in
  Linux)   PLATFORM="linux" ;;
  Darwin)  PLATFORM="macos" ;;
  *)
    echo "ERROR: unsupported OS: $OS_NAME"
    echo "Supported: Linux, macOS (Darwin)"
    exit 1
    ;;
esac

echo "Detected platform: $PLATFORM"

if [ "$PLATFORM" = "macos" ] && [ "$OLLAMA_DOCKER" = "1" ]; then
  cat <<'WARN'

WARNING: --ollama-docker on macOS will run Ollama on CPU only.
         Docker Desktop cannot pass Apple Silicon GPU into containers.
         Consider running Ollama on the host instead.

WARN
  printf "Continue anyway? [y/N]: "
  read -r ANSWER
  case "$ANSWER" in
    y|Y|yes|YES) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

if [ "$OLLAMA_DOCKER" = "1" ]; then
  echo "Mode: Ollama in Docker"
  CONFIG_SRC="$REPO_DIR/config/config.yaml.ollama-docker.example"
else
  echo "Mode: Host Ollama (default)"
  CONFIG_SRC="$REPO_DIR/config/config.yaml.example"
fi

# ---------------------------------------------------------------------------
# Portable in-place sed (GNU sed vs BSD sed on macOS)
# ---------------------------------------------------------------------------
sed_inplace() {
  if [ "$PLATFORM" = "macos" ]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

# ---------------------------------------------------------------------------
# 1. Required commands
# ---------------------------------------------------------------------------
echo "[1/7] Checking required commands..."
for cmd in git docker curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: $cmd is not installed."
    if [ "$PLATFORM" = "macos" ]; then
      echo "Hint: brew install $cmd"
    fi
    exit 1
  fi
done

if ! docker compose version >/dev/null 2>&1; then
  echo "ERROR: docker compose is not available."
  if [ "$PLATFORM" = "macos" ]; then
    echo "Hint: install Docker Desktop for Mac (https://www.docker.com/products/docker-desktop/)"
  fi
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Directories
# ---------------------------------------------------------------------------
echo "[2/7] Creating directories..."
mkdir -p "$HOME/.hermes"
mkdir -p "$HOME/workspace"
if [ "$OLLAMA_DOCKER" = "1" ]; then
  # Pre-create so the bind mount has correct ownership.
  mkdir -p "$HOME/.ollama"
fi

# ---------------------------------------------------------------------------
# 3. .env
# ---------------------------------------------------------------------------
echo "[3/7] Creating .env from .env.example..."
if [ ! -f "$REPO_DIR/.env" ]; then
  cp "$REPO_DIR/.env.example" "$REPO_DIR/.env"
fi

UID_VAL="$(id -u)"
GID_VAL="$(id -g)"

echo "      Host UID: ${UID_VAL}, GID: ${GID_VAL}"

sed_inplace "s/^HOST_UID=.*/HOST_UID=${UID_VAL}/"     "$REPO_DIR/.env"
sed_inplace "s/^HOST_GID=.*/HOST_GID=${GID_VAL}/"     "$REPO_DIR/.env"
sed_inplace "s/^WANTED_UID=.*/WANTED_UID=${UID_VAL}/" "$REPO_DIR/.env"
sed_inplace "s/^WANTED_GID=.*/WANTED_GID=${GID_VAL}/" "$REPO_DIR/.env"

# ---------------------------------------------------------------------------
# 4. config.yaml
# ---------------------------------------------------------------------------
echo "[4/7] Creating Hermes config..."
echo "      Source: $(basename "$CONFIG_SRC")"
if [ ! -f "$HOME/.hermes/config.yaml" ]; then
  cp "$CONFIG_SRC" "$HOME/.hermes/config.yaml"
else
  cp "$HOME/.hermes/config.yaml" "$HOME/.hermes/config.yaml.bak.$(date +%Y%m%d-%H%M%S)"
  cp "$CONFIG_SRC" "$HOME/.hermes/config.yaml"
fi

# ---------------------------------------------------------------------------
# 5. Permissions
# ---------------------------------------------------------------------------
echo "[5/7] Fixing permissions..."
TARGETS=("$HOME/.hermes" "$HOME/workspace")
if [ "$OLLAMA_DOCKER" = "1" ]; then
  TARGETS+=("$HOME/.ollama")
fi

if [ "$PLATFORM" = "linux" ]; then
  sudo chown -R "${UID_VAL}:${GID_VAL}" "${TARGETS[@]}"
else
  chown -R "${UID_VAL}:${GID_VAL}" "${TARGETS[@]}" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# 6. Ollama check
# ---------------------------------------------------------------------------
echo "[6/7] Checking Ollama..."
if [ "$OLLAMA_DOCKER" = "1" ]; then
  echo "      Skipped: Ollama will run inside Docker."
elif ! curl -fsS http://127.0.0.1:11434/api/tags >/dev/null; then
  echo "WARNING: Ollama is not reachable at http://127.0.0.1:11434"
  echo
  if [ "$PLATFORM" = "linux" ]; then
    echo "Linux (systemd) configuration:"
    echo "  sudo systemctl edit ollama"
    echo '  [Service]'
    echo '  Environment="OLLAMA_HOST=0.0.0.0:11434"'
    echo "  sudo systemctl daemon-reload"
    echo "  sudo systemctl restart ollama"
  else
    echo "macOS configuration:"
    echo "  # If installed via the Mac app:"
    echo '  launchctl setenv OLLAMA_HOST "0.0.0.0:11434"'
    echo "  # Then quit and relaunch the Ollama app from the menu bar."
    echo
    echo "  # If installed via Homebrew:"
    echo '  brew services stop ollama'
    echo '  OLLAMA_HOST=0.0.0.0:11434 brew services start ollama'
  fi
  echo
fi

# ---------------------------------------------------------------------------
# 7. Upstream sources
# ---------------------------------------------------------------------------
echo "[7/7] Cloning upstream repositories if missing..."
if [ ! -d "$REPO_DIR/hermes-webui" ]; then
  git clone https://github.com/nesquena/hermes-webui.git "$REPO_DIR/hermes-webui"
fi

if [ ! -d "$REPO_DIR/hermes-hudui/.git" ]; then
  rm -rf "$REPO_DIR/hermes-hudui-src"
  git clone https://github.com/joeynyc/hermes-hudui.git "$REPO_DIR/hermes-hudui-src"

  TMP_DOCKERFILE="$(mktemp -t hermes-hudui-dockerfile.XXXXXX)"
  cp "$REPO_DIR/hermes-hudui/Dockerfile" "$TMP_DOCKERFILE"
  rm -rf "$REPO_DIR/hermes-hudui"
  mv "$REPO_DIR/hermes-hudui-src" "$REPO_DIR/hermes-hudui"
  cp "$TMP_DOCKERFILE" "$REPO_DIR/hermes-hudui/Dockerfile"
  rm -f "$TMP_DOCKERFILE"
fi

echo
echo "Setup completed."
echo
echo "Next:"
if [ "$OLLAMA_DOCKER" = "1" ]; then
  echo "  docker compose -f docker-compose.yml -f compose.ollama.yml up -d --build"
  echo
  echo "Then pull a model into the Docker Ollama:"
  echo "  docker exec -it ollama ollama pull gemma4:e4b"
else
  echo "  docker compose up -d --build"
fi
echo
echo "Access:"
echo "  Hermes WebUI : http://127.0.0.1:8787"
echo "  Hermes HUDUI : http://127.0.0.1:3001"
