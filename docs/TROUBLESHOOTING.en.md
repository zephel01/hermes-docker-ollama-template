# Troubleshooting

> [日本語版: TROUBLESHOOTING.md](TROUBLESHOOTING.md)

Always start with [`./scripts/check.sh`](../scripts/check.sh) to isolate which layer is broken.

## Table of contents

- [`Connection error`](#connection-error)
- [`Provider 'custom:gemma4' is set but no API key was found`](#provider-customgemma4-is-set-but-no-api-key-was-found)
- [WebUI shows Gemini / GPT / DeepSeek entries](#webui-shows-gemini--gpt--deepseek-entries)
- [`/tmp/hermeswebui_root_env.txt: Permission denied`](#tmphermeswebui_root_envtxt-permission-denied)
- [`HERMES_WEBUI_STATE_DIR not set`](#hermes_webui_state_dir-not-set)
- [`mkdir: cannot create directory '/home/...': Permission denied`](#mkdir-cannot-create-directory-home-permission-denied)
- [MCP server `missing executable uvx`](#mcp-server-missing-executable-uvx)
- [`hermes-hudui` won't start](#hermes-hudui-wont-start)
- [LLM responses are extremely slow](#llm-responses-are-extremely-slow)
- [Cannot log into WebUI](#cannot-log-into-webui)
- [SearXNG issues](#searxng-issues)

---

## `Connection error`

When WebUI chat shows "Connection error", check logs first:

```bash
docker compose logs --tail=120 hermes-webui
```

If you see:

```text
Endpoint: http://127.0.0.1:11434/v1
```

your config is wrong. The correct value is:

```text
http://host.docker.internal:11434/v1
```

Verify reachability from inside the container:

```bash
docker exec -it hermes-webui bash -lc \
  'curl -s http://host.docker.internal:11434/v1/models | head'
```

If it doesn't connect, make sure host Ollama is listening on `0.0.0.0:11434`.

Linux:

```bash
sudo systemctl status ollama
ss -tlnp | grep 11434
```

macOS:

```bash
launchctl getenv OLLAMA_HOST            # Mac app
ps aux | grep ollama
lsof -nP -iTCP:11434 -sTCP:LISTEN
```

You want to see `*:11434 (LISTEN)` (i.e. `0.0.0.0`). If only `127.0.0.1:11434 (LISTEN)` shows up, the env change isn't being picked up.

---

## `Provider 'custom:gemma4' is set but no API key was found`

The `:` in the model name was parsed as a provider prefix.

Switch to a **Custom endpoint** config:

```yaml
model:
  provider: custom
  default: "gemma4:e4b"
  base_url: "http://host.docker.internal:11434/v1"
  api_key: ""
```

Then reset WebUI state:

```bash
./scripts/reset-webui.sh
```

---

## WebUI shows Gemini / GPT / DeepSeek entries

`model_catalog` is enabled. Disable it:

```yaml
model_catalog:
  enabled: false
```

Then clear WebUI state cache:

```bash
./scripts/reset-webui.sh
```

---

## `/tmp/hermeswebui_root_env.txt: Permission denied`

`/tmp` inside the `hermes-webui` container is not writable.
Make sure `docker-compose.yml` includes:

```yaml
hermes-webui:
  ...
  tmpfs:
    - /tmp:rw,nosuid,nodev,mode=1777
```

---

## `HERMES_WEBUI_STATE_DIR not set`

The required env var is missing or empty.

```env
HERMES_WEBUI_STATE_DIR=/home/hermeswebui/.hermes/webui
```

> [!IMPORTANT]
> Do not use a host absolute path (e.g. `/home/zephel01/.hermes/webui`). The container user has no write permission there.

---

## `mkdir: cannot create directory '/home/...': Permission denied`

A host path is leaking into `.env`.

Wrong:

```env
HERMES_WEBUI_STATE_DIR=/home/zephel01/.hermes/webui
```

Right:

```env
HERMES_WEBUI_STATE_DIR=/home/hermeswebui/.hermes/webui
```

---

## MCP server `missing executable uvx`

```text
missing executable '/home/USER/works/hermes/.venv/bin/uvx'
```

A host absolute path is in `~/.hermes/mcp.yaml`.

Recovery order:

1. Disable MCP completely
2. `docker compose restart`
3. Confirm normal chat works
4. Re-enable MCP one server at a time, using container-internal paths

---

## `hermes-hudui` won't start

The upstream repo layout (e.g. `pyproject.toml` paths) may have shifted.
The bundled `hermes-hudui/Dockerfile` targets the latest commit; for other commits, adjust the `COPY` lines accordingly.

```bash
docker compose logs --tail=120 hermes-hudui
docker compose build --no-cache hermes-hudui
docker compose up -d hermes-hudui
```

---

## LLM responses are extremely slow

- Confirm the host GPU is detected: `nvidia-smi`
- Confirm Ollama is using the GPU: `ollama ps`
- Switch to a smaller model:

```bash
ollama pull qwen2.5:3b
```

Update `model.default` in `config.yaml`, then `docker compose restart`.

---

## Cannot log into WebUI

You probably changed `HERMES_WEBUI_PASSWORD` in `.env` but are using an old password.
Clear browser cache / cookies and log in again with the current `.env` value.

If that still fails, reset WebUI state:

```bash
./scripts/reset-webui.sh
```

---

## SearXNG issues

Search-stack-specific issues live in [SEARCH.en.md](SEARCH.en.md). Common ones:

- `searxng` container keeps restarting → `SEARXNG_SECRET_KEY` is not set
- `format=json` returns 404 / 403 → `formats: [html, json]` missing from `searxng/settings.yml`
- Hermes can't reach SearXNG → forgot to pass `compose.search.yml` on `up`
- MCP server `command not found` → `mcp-searxng` (npm) runtime (Node.js) missing inside the container

See [SEARCH.en.md](SEARCH.en.md) for the full diagnostic flow.
