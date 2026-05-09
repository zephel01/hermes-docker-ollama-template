# Installation Guide

> [日本語版: INSTALL.md](INSTALL.md)

A more detailed walkthrough of the Quick Start in [README.en.md](../README.en.md).

## Table of contents

- [Requirements](#requirements)
- [1. Install Docker](#1-install-docker)
- [2. Install Ollama](#2-install-ollama)
- [3. Make Ollama reachable from Docker](#3-make-ollama-reachable-from-docker)
- [4. Set up this template](#4-set-up-this-template)
- [5. Start and verify](#5-start-and-verify)
- [6. Uninstall](#6-uninstall)

---

## Requirements

| Item | Recommended |
|---|---|
| OS | Linux (Ubuntu 22.04+ / Debian 12+ / Arch / Fedora 39+) or **macOS 13+ (Apple Silicon / Intel)** |
| CPU | x86_64 or arm64 (Apple Silicon). Without a GPU, prefer small models. |
| RAM | 16 GB or more |
| Disk | 30 GB+ free |
| Network | Tailscale recommended |

---

## 1. Install Docker

### Linux (Ubuntu / Debian)

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"
newgrp docker
docker compose version
```

### Linux (Arch)

```bash
sudo pacman -S docker docker-compose
sudo systemctl enable --now docker.service
sudo usermod -aG docker "$USER"
```

### macOS

Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) or [OrbStack](https://orbstack.dev/). On Apple Silicon, OrbStack is lighter.

```bash
# Homebrew
brew install --cask docker          # Docker Desktop
# or
brew install --cask orbstack        # OrbStack
```

Verify:

```bash
docker run --rm hello-world
docker compose version
```

> [!TIP]
> Docker Desktop and OrbStack on macOS support `host.docker.internal` out of the box — no extra config needed.

---

## 2. Install Ollama

### Linux

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### macOS

Install the [Ollama Mac app](https://ollama.com/download), or via Homebrew:

```bash
brew install ollama
```

### Pull a model (both platforms)

```bash
ollama pull gemma4:e4b
ollama list
```

Any model works — just keep `model.default` in `config/config.yaml.example` in sync.

---

## 3. Make Ollama reachable from Docker

> [!IMPORTANT]
> Docker containers cannot reach the host via `127.0.0.1:11434`. Bind Ollama to `0.0.0.0:11434`.

### Linux (systemd)

```bash
sudo systemctl edit ollama
```

Add:

```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
```

Apply:

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
sudo systemctl status ollama
curl http://127.0.0.1:11434/api/tags
```

### macOS (Ollama Mac app)

```bash
launchctl setenv OLLAMA_HOST "0.0.0.0:11434"
```

Then quit Ollama from the menu bar and relaunch.

```bash
curl http://127.0.0.1:11434/api/tags
```

> [!NOTE]
> `launchctl setenv` is cleared on reboot. To persist, add a plist under `~/Library/LaunchAgents/` or use the Mac app's settings UI (Ollama 0.5+ supports setting `OLLAMA_HOST` from settings).

### macOS (Homebrew)

```bash
brew services stop ollama
OLLAMA_HOST=0.0.0.0:11434 brew services start ollama
curl http://127.0.0.1:11434/api/tags
```

### Firewall

> [!WARNING]
> `0.0.0.0` exposes Ollama on your LAN. Pair with Tailscale or block 11434.

Linux:

```bash
sudo ufw deny 11434/tcp
sudo ufw reload
```

macOS:

```bash
# System Settings → Network → Firewall
# Or use Little Snitch / LuLu to restrict 11434
```

---

## 4. Set up this template

```bash
git clone https://github.com/YOUR_NAME/hermes-docker-ollama-template.git
cd hermes-docker-ollama-template

chmod +x scripts/*.sh
./scripts/setup.sh
```

`setup.sh` auto-detects Linux vs macOS and:

1. Verifies `git`, `docker`, `curl` are installed
2. Creates `~/.hermes` and `~/workspace`
3. Generates `.env` from `.env.example`, fills in UID / GID
4. Copies `config/config.yaml.example` to `~/.hermes/config.yaml` (backs up existing)
5. Fixes permissions (best-effort on macOS, mostly unnecessary there)
6. Probes Ollama and shows OS-specific fix instructions if unreachable
7. Clones `hermes-webui` and `hermes-hudui` sources if missing

> [!TIP]
> Always change `HERMES_WEBUI_PASSWORD` in `.env`.

> [!NOTE]
> `HOST_UID` / `HOST_GID` are auto-filled by `setup.sh` from `id -u` / `id -g`.
> macOS default users are typically `501:20`, while Linux first users are usually `1000:1000`.
> The `1000` placeholder in `.env.example` will mismatch on macOS — always run `setup.sh` rather than copying `.env.example` by hand.

### Run Ollama in Docker (Linux + GPU recommended)

A second mode runs Ollama as a container instead of on the host:

```bash
./scripts/setup.sh --ollama-docker
docker compose -f docker-compose.yml -f compose.ollama.yml up -d --build

# First-time model pull into the container
docker exec -it ollama ollama pull gemma4:e4b
```

For NVIDIA GPU support, uncomment the `deploy.resources.reservations.devices` block in `compose.ollama.yml`. NVIDIA Container Toolkit must be installed on the host.

> [!WARNING]
> Using `--ollama-docker` on macOS falls back to CPU inference (Docker Desktop cannot pass Apple Silicon GPU into containers). Stick with host Ollama on Mac.

### Enable Web search (SearXNG)

```bash
./scripts/setup.sh --with-search
docker compose -f docker-compose.yml -f compose.search.yml up -d --build
```

`setup.sh --with-search` does:

- Creates `searxng/settings.yml` (with `formats: [html, json]` enabled)
- Appends a 64-char `SEARXNG_SECRET_KEY` to `.env`
- Copies the SearXNG MCP entry to `~/.hermes/mcp.yaml`

Combine with `--ollama-docker`:

```bash
docker compose \
  -f docker-compose.yml \
  -f compose.ollama.yml \
  -f compose.search.yml \
  up -d --build
```

See [SEARCH.en.md](SEARCH.en.md) for the full guide.

---

## 5. Start and verify

```bash
docker compose up -d --build
docker compose ps
./scripts/check.sh
```

Open in your browser:

- WebUI: http://127.0.0.1:8787
- HUD UI: http://127.0.0.1:3001

Send a chat message to `gemma4:e4b`. If you get a response, you're good. If not, see [TROUBLESHOOTING.en.md](TROUBLESHOOTING.en.md).

---

## 6. Uninstall

```bash
cd hermes-docker-ollama-template
docker compose down -v
```

To wipe everything:

```bash
rm -rf ~/.hermes ~/workspace
docker volume prune -f
docker image rm nousresearch/hermes-agent:latest || true
```

> [!CAUTION]
> `~/.hermes` may contain chat history, memory, and API keys. Back it up before deleting.
