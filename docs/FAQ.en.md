# FAQ

> [日本語版: FAQ.md](FAQ.md)

## Table of contents

- [Q. Does this work on macOS / WSL2?](#q-does-this-work-on-macos--wsl2)
- [Q. Is an NVIDIA GPU required?](#q-is-an-nvidia-gpu-required)
- [Q. Which model should I try first?](#q-which-model-should-i-try-first)
- [Q. Can I use OpenAI / Claude API alongside Ollama?](#q-can-i-use-openai--claude-api-alongside-ollama)
- [Q. How do I switch between multiple models?](#q-how-do-i-switch-between-multiple-models)
- [Q. How do I change port numbers?](#q-how-do-i-change-port-numbers)
- [Q. I only want to expose this inside my tailnet](#q-i-only-want-to-expose-this-inside-my-tailnet)
- [Q. How is this different from ChatGPT / Claude.ai?](#q-how-is-this-different-from-chatgpt--claudeai)
- [Q. Is any data sent externally?](#q-is-any-data-sent-externally)
- [Q. I want to keep my existing `~/.hermes`](#q-i-want-to-keep-my-existing-hermes)
- [Q. How do I update?](#q-how-do-i-update)
- [Q. Where are the prompt logs?](#q-where-are-the-prompt-logs)

---

## Q. Does this work on macOS / WSL2?

**A.** **macOS is officially supported.** Both Apple Silicon and Intel Macs work.

- Use [Docker Desktop](https://www.docker.com/products/docker-desktop/) or [OrbStack](https://orbstack.dev/). `host.docker.internal` is enabled by default.
- For Ollama, use either the Mac app or Homebrew install. Set the listen address with `launchctl setenv OLLAMA_HOST "0.0.0.0:11434"` or `OLLAMA_HOST=0.0.0.0:11434 brew services start ollama`.
- `setup.sh` auto-detects the OS, so the install steps are identical to Linux.

WSL2 setups vary widely — please file an issue with your host OS / WSL version / Docker Desktop status.

---

## Q. Is an NVIDIA GPU required?

**A.** No, but performance suffers without one. CPU-only is workable with small models like `qwen2.5:3b` or `phi3:mini`.

---

## Q. Which model should I try first?

**A.** With a GPU:

```bash
ollama pull gemma4:e4b
```

CPU-only:

```bash
ollama pull qwen2.5:3b
```

Make sure `model.default` in `config.yaml` matches what you pulled.

---

## Q. Can I use OpenAI / Claude API alongside Ollama?

**A.** Yes, via `fallback_providers`:

```yaml
model:
  provider: custom
  default: "gemma4:e4b"
  base_url: "http://host.docker.internal:11434/v1"
  api_key: ""

fallback_providers:
  - name: openai
    api_key_env: OPENAI_API_KEY
    models:
      - gpt-4o
      - gpt-4o-mini
```

Set `OPENAI_API_KEY` in `.env` and `docker compose up -d`.

---

## Q. How do I switch between multiple models?

**A.** Use the model selector in the WebUI. Behind the scenes it points at the same Ollama server with a different model name. Make sure to `ollama pull` them first.

---

## Q. How do I change port numbers?

**A.** Edit `ports:` in `docker-compose.yml`:

```yaml
ports:
  - "127.0.0.1:18787:8787"
```

Also update `HERMES_WEBUI_PORT` in `.env`.

---

## Q. I only want to expose this inside my tailnet

**A.** Default binds are already `127.0.0.1`, so LAN and internet can't reach it.
For tailnet exposure:

```bash
./scripts/tailscale-serve.sh
```

See [SECURITY.en.md](SECURITY.en.md) for details.

---

## Q. How is this different from ChatGPT / Claude.ai?

**A.** Main differences:

- **Local execution**: input and output never leave your machine
- **Model freedom**: switch open-weight models via Ollama
- **MCP / custom tools**: agents can call your own scripts
- **Cost**: electricity only

The trade-off is response quality, which depends on your GPU and chosen model.

---

## Q. Is any data sent externally?

**A.** Default config keeps everything local.

- LLM inference happens on host Ollama
- WebUI / HUD UI / Agent are all bound to `127.0.0.1`
- If you enable `fallback_providers` (OpenAI, Claude, etc.), data goes to that vendor

---

## Q. I want to keep my existing `~/.hermes`

**A.** `setup.sh` backs up `~/.hermes/config.yaml` before overwriting:

```text
~/.hermes/config.yaml.bak.20260510-120000
```

Delete it when you no longer need it.

---

## Q. How do I update?

**A.**

```bash
cd hermes-docker-ollama-template
git pull origin main
docker compose pull
docker compose up -d --build
```

If WebUI shows stale state:

```bash
./scripts/reset-webui.sh
```

---

## Q. Where are the prompt logs?

**A.** Under `~/.hermes/`. Exact file names depend on the Hermes Agent version:

```bash
find ~/.hermes -type f -mtime -1
```

shows recently modified files.
