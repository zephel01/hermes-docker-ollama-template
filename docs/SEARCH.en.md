# Enable Web Search — SearXNG + Crawl4AI

> [日本語版: SEARCH.md](SEARCH.md)

Hermes by itself can't search the web or fetch pages. With `compose.search.yml` you get a fully local search stack:

## Architecture

```text
[ Hermes Agent ]
   │
   │ MCP
   ├──→ [ SearXNG ]    : meta-search (Google/Bing/DuckDuckGo aggregation)
   │                     http://searxng:8080
   │
   └──→ [ Crawl4AI ]   : page fetcher (Playwright, supports dynamic pages)
                          http://crawl4ai:11235
```

Both run locally — no external API keys needed.

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
| Disk | ~2 GB (Crawl4AI bundles Chromium) |
| RAM | ~700 MB (SearXNG ~200MB + Crawl4AI ~500MB) |
| First boot | 1–3 minutes (Chromium download) |

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

### Crawl4AI

```bash
curl http://127.0.0.1:11235/health
```

`{"status":"ok"}` (or similar) means OK.

Quick crawl:

```bash
curl -X POST http://127.0.0.1:11235/crawl \
  -H 'Content-Type: application/json' \
  -d '{"urls": ["https://example.com"]}'
```

### Container-to-container reachability

```bash
docker exec hermes-agent sh -lc 'curl -s http://searxng:8080/healthz'
docker exec hermes-agent sh -lc 'curl -s http://crawl4ai:11235/health'
```

If both respond, Hermes Agent can reach them.

---

## Wire it up to Hermes via MCP

`config/mcp.yaml.example` ships `searxng` and `crawl4ai` MCP server entries. After running `setup.sh --with-search`, they're already at `~/.hermes/mcp.yaml`.

```yaml
mcp:
  servers:
    searxng:
      command: "npx"
      args: ["-y", "mcp-searxng"]
      env:
        SEARXNG_URL: "http://searxng:8080"
    crawl4ai:
      command: "uvx"
      args: ["mcp-crawl4ai"]
      env:
        CRAWL4AI_URL: "http://crawl4ai:11235"
```

> [!WARNING]
> These MCP servers are community projects; package names and args may shift. If something doesn't run, check each repo's current README:
> - [mcp-searxng](https://github.com/ihor-sokoliuk/mcp-searxng)
> - [mcp-crawl4ai-rag](https://github.com/coleam00/mcp-crawl4ai-rag)

> [!IMPORTANT]
> Never put host absolute paths (e.g. `/home/USER/...`) into MCP config. They don't exist inside the container. Use commands resolvable via container PATH like `npx` or `uvx`.

Restart the agent:

```bash
docker compose restart hermes-agent
```

---

## Privacy / security

- **Queries do leave your machine.** SearXNG is a meta-search proxy, so queries ultimately hit Google / Bing / etc. It improves your fingerprint hygiene relative to those engines, but it's not zero telemetry.
- **Page contents stay local.** Crawl4AI processes fetched pages inside the container; nothing is sent outward.
- **Ports are `127.0.0.1`-bound.** SearXNG (8080) and Crawl4AI (11235) are not exposed publicly by default.
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

### Crawl4AI is super slow on the first crawl

Chromium is being downloaded the first time. Watch `docker compose logs -f crawl4ai`.

### Hermes can't reach SearXNG / Crawl4AI

Verify container-to-container DNS:

```bash
docker exec hermes-agent sh -lc 'curl -s http://searxng:8080/healthz'
```

If it fails, you probably forgot to pass `compose.search.yml`. Confirm with `docker compose ps` — `searxng` and `crawl4ai` should be listed.

### MCP server fails to start / `command not found`

`mcp-searxng` is an npm package; `mcp-crawl4ai` is a uvx package. Both require their respective runtimes (Node / uv) inside the `hermes-agent` container. If the upstream image doesn't ship them, you may need to provide a wrapper or a dedicated MCP container. See each MCP server's README for details.
