# Enable Web Search — SearXNG

> [日本語版: SEARCH.md](SEARCH.md)

Hermes by itself can't search the web. This template bundles SearXNG into the base `docker-compose.yml` so Hermes' built-in `web_search` tool routes through it (enabled by default).

## Architecture

```text
[ Hermes Agent ]
   │  web_search tool (Hermes native)
   │
   └──→ [ SearXNG ]    : meta-search (Google/Bing/DuckDuckGo aggregation)
                         http://searxng:8080
```

It runs locally — no external API keys needed. Hermes' built-in web tools call SearXNG directly.

> **Need page extraction (extract / crawl)?**
> SearXNG is search-only. If you also need readable page contents, pair it with an extract provider such as Firecrawl, Tavily, or Exa via `web.extract_backend` in `~/.hermes/config.yaml`. See the [Hermes docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/web-search) for details.

## Table of contents

- [Resource cost](#resource-cost)
- [Setup](#setup)
- [Verify](#verify)
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

### 1. Run setup

```bash
./scripts/setup.sh
```

This will:

- Create `searxng/settings.yml` from `searxng/settings.yml.example` (JSON API enabled)
- Append a 64-char random `SEARXNG_SECRET_KEY` to `.env` (compose-side)
- **Append `SEARXNG_URL=http://searxng:8080` to `~/.hermes/.env`** (Hermes Agent side ★required)
- Append `web.search_backend: "searxng"` to `~/.hermes/config.yaml` (kept if already present)

### 2. Start

```bash
docker compose up -d --build
```

Combine with Ollama-in-Docker mode:

```bash
docker compose -f docker-compose.yml -f compose.ollama.yml up -d --build
```

### 3. What the config files look like (manual setup reference)

If you'd rather wire this up by hand:

**`~/.hermes/config.yaml`** — append:

```yaml
web:
  search_backend: "searxng"
  # extract_backend: "firecrawl"   # add if you also want page extraction
```

**`~/.hermes/.env`** — append (★this is the gotcha):

```bash
SEARXNG_URL=http://searxng:8080
```

> [!IMPORTANT]
> `SEARXNG_URL` is read from **`~/.hermes/.env`**.
> Setting it in `docker-compose.yml`'s `environment:` block does **not** work — Hermes Agent reads via dotenv and ignores process env for this var.
> If you see `Could not reach SearXNG at http://localhost:8888` after configuring everything, check `~/.hermes/.env` first.

---

## Verify

### SearXNG itself

```bash
# from the host
curl 'http://127.0.0.1:8080/search?q=hermes+nous+research&format=json' | head -c 500
```

If JSON with `results: [...]` comes back, you're good. You can also browse to http://127.0.0.1:8080 — SearXNG works as a regular meta-search engine.

### From inside the hermes-agent container

The `hermes-agent` image doesn't ship `wget`, so use Python:

```bash
# (1) is ~/.hermes/.env visible?
docker exec hermes-agent sh -lc 'cat /home/hermes/.hermes/.env | grep SEARXNG'

# (2) container-to-container reachability
docker exec hermes-agent python3 -c "
import urllib.request
print(urllib.request.urlopen('http://searxng:8080/healthz', timeout=5).read().decode())
"

# (3) JSON API
docker exec hermes-agent python3 -c "
import urllib.request, json
r = urllib.request.urlopen('http://searxng:8080/search?q=hello&format=json', timeout=10).read()
d = json.loads(r); print(f'{len(d[\"results\"])} results')
"
```

### From the Hermes Agent itself

Open a **new chat** in the WebUI (http://127.0.0.1:8787) and try:

> Search the web for today's weather in Tokyo.

If the `web_search` tool fires through SearXNG and results come back, you're done.

---

## Privacy / security

- **Queries do leave your machine.** SearXNG is a meta-search proxy, so queries ultimately hit Google / Bing / etc. It improves your fingerprint hygiene relative to those engines, but it's not zero telemetry.
- **For a more private setup**, drop Google / Bing from `searxng/settings.yml` `engines:` and keep only DuckDuckGo / Brave / Wikipedia.
- **Port is `127.0.0.1`-bound.** SearXNG (8080) is not exposed publicly by default.
- **`SEARXNG_SECRET_KEY` lives in `.env`.** The repo `.env` is git-ignored.

---

## Troubleshooting

### Hermes says `Could not reach SearXNG at http://localhost:8888`

`SEARXNG_URL=http://searxng:8080` is not present in `~/.hermes/.env`, or the agent didn't reload it. Hermes falls back to the default `http://localhost:8888` when `SEARXNG_URL` is unset.

```bash
# check what's in the env file
docker exec hermes-agent sh -lc 'grep SEARXNG /home/hermes/.hermes/.env'

# add it if missing
echo "SEARXNG_URL=http://searxng:8080" >> ~/.hermes/.env
docker compose restart hermes-agent
```

Setting it via `docker-compose.yml` `environment:` does **not** work — it must be in `~/.hermes/.env`.

### Hermes says `Could not reach SearXNG at http://searxng:8080`

URL is read correctly but connection failed = network issue.

```bash
# both containers on the same network?
docker network ls | grep hermes
# → hermes-net (or project-prefixed name)

docker exec hermes-agent python3 -c "
import urllib.request
print(urllib.request.urlopen('http://searxng:8080/healthz', timeout=5).read())
"
```

### SearXNG container restarts in a loop

Almost always a missing `SEARXNG_SECRET_KEY`.

```bash
grep SEARXNG_SECRET_KEY .env
```

If empty, re-run `setup.sh` or manually add a 32+ character random string.

### `format=json` returns 404 / 403

Make sure `formats: [html, json]` is in `searxng/settings.yml`:

```bash
grep -A4 'formats:' searxng/settings.yml
```

If not, regenerate from `searxng/settings.yml.example`.

### Hermes can't reach SearXNG

Verify container-to-container DNS:

```bash
docker exec hermes-agent python3 -c "
import urllib.request
print(urllib.request.urlopen('http://searxng:8080/healthz', timeout=5).read().decode())
"
```

If it fails, the `searxng` container probably isn't running. Confirm with `docker compose ps` — `searxng` should be listed.
