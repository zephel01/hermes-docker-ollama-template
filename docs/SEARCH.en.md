# Enable Web Search — SearXNG

> [日本語版: SEARCH.md](SEARCH.md)

Hermes by itself can't search the web. With `compose.search.yml` you get a fully local meta-search stack:

## Architecture

```text
[ Hermes Agent ]
   │
   │ MCP
   └──→ [ SearXNG ]    : meta-search (Google/Bing/DuckDuckGo aggregation)
                         http://searxng:8080
```

It runs locally — no external API keys needed.

> **Need page extraction (extract / crawl)?**
> SearXNG is search-only. If you also need readable page contents, pair it with an extract provider such as Firecrawl, Tavily, or Exa via `web.extract_backend` in `~/.hermes/config.yaml`. See the [Hermes docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/web-search) for details.

## Table of contents

- [Resource cost](#resource-cost)
- [Setup](#setup)
- [Verify](#verify)
- [Wire it up to Hermes via MCP](#wire-it-up-to-hermes-via-mcp)
- [Privacy / security](#privacy--security)
- [Troubleshooting](#troubleshooting)

---

## Resource cost

| Item | Approx |
|---|---|
| Disk | ~200 MB (SearXNG image) |
| RAM | ~200 MB |
| First boot | tens of seconds |

---

## Setup

### 1. Re-run setup with the flag

```bash
./scripts/setup.sh --with-search
```

This will:

- Create `searxng/settings.yml` from `searxng/settings.yml.example`
- Append a 64-char random `SEARXNG_SECRET_KEY` to `.env`
- Copy `config/mcp.yaml.example` to `~/.hermes/mcp.yaml` (kept if it already exists)

### 2. Start with the override

```bash
docker compose -f docker-compose.yml -f compose.search.yml up -d --build
```

Combine with Ollama-in-Docker mode:

```bash
docker compose \
  -f docker-compose.yml \
  -f compose.ollama.yml \
  -f compose.search.yml \
  up -d --build
```

---

## Verify

### SearXNG

```bash
curl 'http://127.0.0.1:8080/search?q=hermes+nous+research&format=json' | head -c 500
```

If JSON with `results: [...]` comes back, you're good.

You can also browse to http://127.0.0.1:8080 — SearXNG works as a regular meta-search engine.

### Container-to-container reachability

```bash
docker exec hermes-agent sh -lc 'curl -s http://searxng:8080/healthz'
```

If it responds, Hermes Agent can reach it.

---

## Wire it up to Hermes via MCP

`config/mcp.yaml.example` ships a `searxng` MCP server entry. After running `setup.sh --with-search`, it's already at `~/.hermes/mcp.yaml`.

```yaml
mcp:
  servers:
    searxng:
      command: "npx"
      args: ["-y", "mcp-searxng"]
      env:
        SEARXNG_URL: "http://searxng:8080"
```

> [!WARNING]
> This MCP server is a community project; package name and args may shift. If something doesn't run, check the current README:
> - [mcp-searxng](https://github.com/ihor-sokoliuk/mcp-searxng)

> [!IMPORTANT]
> Never put host absolute paths (e.g. `/home/USER/...`) into MCP config. They don't exist inside the container. Use commands resolvable via container PATH like `npx`.

Restart the agent:

```bash
docker compose restart hermes-agent
```

---

## Privacy / security

- **Queries do leave your machine.** SearXNG is a meta-search proxy, so queries ultimately hit Google / Bing / etc. It improves your fingerprint hygiene relative to those engines, but it's not zero telemetry.
- **Port is `127.0.0.1`-bound.** SearXNG (8080) is not exposed publicly by default.
- **`SEARXNG_SECRET_KEY` lives in `.env`.** `.env` is git-ignored.

---

## Troubleshooting

### SearXNG container restarts in a loop

Almost always a missing `SEARXNG_SECRET_KEY`.

```bash
grep SEARXNG_SECRET_KEY .env
```

If empty, re-run `setup.sh --with-search` or manually add a 32+ character random string.

### `format=json` returns 404 / 403

Make sure `formats: [html, json]` is in `searxng/settings.yml`:

```bash
grep -A4 'formats:' searxng/settings.yml
```

If not, regenerate from `searxng/settings.yml.example`.

### Hermes can't reach SearXNG

Verify container-to-container DNS:

```bash
docker exec hermes-agent sh -lc 'curl -s http://searxng:8080/healthz'
```

If it fails, you probably forgot to pass `compose.search.yml`. Confirm with `docker compose ps` — `searxng` should be listed.

### MCP server fails to start / `command not found`

`mcp-searxng` is an npm package, so Node.js must be available inside the `hermes-agent` container. If the upstream image doesn't ship Node, you may need to provide a wrapper or a dedicated MCP container. See the MCP server's README for details.
