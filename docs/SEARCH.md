# Web 検索を有効にする — SearXNG + Crawl4AI

> [English version: SEARCH.en.md](SEARCH.en.md)

Hermes 単体では Web を検索したり外部ページを読みに行く能力はありません。本テンプレートでは、`compose.search.yml` を有効にすることで、ローカル完結の検索基盤を立ち上げられます。

## 構成

```text
[ Hermes Agent ]
   │
   │ MCP
   ├──→ [ SearXNG ]    : メタ検索（Google/Bing/DuckDuckGo を集約）
   │                     http://searxng:8080
   │
   └──→ [ Crawl4AI ]   : ページ取得（Playwright で動的ページ対応）
                          http://crawl4ai:11235
```

両方ともローカルで動くので、外部の検索 API キーは不要です。

## 目次

- [必要リソース](#必要リソース)
- [セットアップ](#セットアップ)
- [動作確認](#動作確認)
- [Hermes に MCP として認識させる](#hermes-に-mcp-として認識させる)
- [プライバシー / セキュリティ](#プライバシー--セキュリティ)
- [トラブルシュート](#トラブルシュート)

---

## 必要リソース

| 項目 | 目安 |
|---|---|
| 追加ディスク | 約 2 GB（Crawl4AI は Chromium を含むため） |
| 追加メモリ | 約 700 MB（SearXNG ~200MB + Crawl4AI ~500MB） |
| 初回起動時間 | 1〜3 分（Chromium バイナリのダウンロード含む） |

---

## セットアップ

### 1. オプション付きで `setup.sh` を再実行

```bash
./scripts/setup.sh --with-search
```

これで以下が自動でセットアップされます。

- `searxng/settings.yml` を `searxng/settings.yml.example` から生成
- `.env` に `SEARXNG_SECRET_KEY` を 64文字のランダム値で追記
- `~/.hermes/mcp.yaml` を `config/mcp.yaml.example` からコピー（既存があれば保持）

### 2. compose を override 付きで起動

```bash
docker compose -f docker-compose.yml -f compose.search.yml up -d --build
```

Ollama も Docker 化したい場合は両方並べます:

```bash
docker compose \
  -f docker-compose.yml \
  -f compose.ollama.yml \
  -f compose.search.yml \
  up -d --build
```

---

## 動作確認

### SearXNG

```bash
curl 'http://127.0.0.1:8080/search?q=hermes+nous+research&format=json' | head -c 500
```

JSON の `results: [...]` が返ってくれば OK。

ブラウザで http://127.0.0.1:8080 を開けば、SearXNG の検索画面が直接使えます（普段使いの検索エンジンとしても便利）。

### Crawl4AI

```bash
curl http://127.0.0.1:11235/health
```

`{"status":"ok"}` のような応答が返れば OK。

簡易クロール:

```bash
curl -X POST http://127.0.0.1:11235/crawl \
  -H 'Content-Type: application/json' \
  -d '{"urls": ["https://example.com"]}'
```

### コンテナ間疎通

```bash
docker exec hermes-agent sh -lc 'curl -s http://searxng:8080/healthz'
docker exec hermes-agent sh -lc 'curl -s http://crawl4ai:11235/health'
```

両方とも応答があれば、Hermes Agent から呼べる状態です。

---

## Hermes に MCP として認識させる

`config/mcp.yaml.example` に `searxng` / `crawl4ai` の MCP server 設定を入れています。`setup.sh --with-search` を実行した時点で、`~/.hermes/mcp.yaml` にコピーされているはずです。

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
> MCP サーバはコミュニティ製で、パッケージ名や引数が変わる可能性があります。動かない場合は各リポジトリの最新 README を確認してください。
> - [mcp-searxng](https://github.com/ihor-sokoliuk/mcp-searxng)
> - [mcp-crawl4ai-rag](https://github.com/coleam00/mcp-crawl4ai-rag)

> [!IMPORTANT]
> MCP の設定にホスト側の絶対パス（例: `/home/USER/...`）を書かないでください。Docker内では存在しません。コマンドは `npx` や `uvx` のようにコンテナ内 PATH で解決できるものを使ってください。

設定後 Agent を再起動:

```bash
docker compose restart hermes-agent
```

---

## プライバシー / セキュリティ

- **検索クエリは外部に出ます**: SearXNG はメタ検索なので、最終的に Google / Bing 等にクエリが飛びます。完全プライベートではありません（ただし SearXNG 側が中継するので、各検索エンジンに対するあなた自身のフットプリントは減ります）。
- **取得したページの内容はローカル**: Crawl4AI が取得したページコンテンツはコンテナ内で処理され、外部に送信されません。
- **ポートは `127.0.0.1` バインド**: SearXNG (8080) も Crawl4AI (11235) も既定でホストに公開しません（テンプレートで `127.0.0.1:port:port` 設定済み）。
- **`SEARXNG_SECRET_KEY` の取り扱い**: `.env` に保存されます。`.env` は `.gitignore` 済み。

---

## トラブルシュート

### `searxng` コンテナが繰り返し再起動する

ほぼ確実に `SEARXNG_SECRET_KEY` 未設定です。

```bash
grep SEARXNG_SECRET_KEY .env
```

無ければ `setup.sh --with-search` を再実行するか、手動で 32 文字以上のランダム文字列を `.env` に書き足してください。

### `format=json` が 404 / 403 を返す

`searxng/settings.yml` に `formats: [html, json]` が入っているか確認:

```bash
grep -A4 'formats:' searxng/settings.yml
```

無ければ `searxng/settings.yml.example` から再生成してください。

### Crawl4AI の最初のクロールが極端に遅い

初回は Playwright の Chromium をダウンロードするため数分かかります。`docker compose logs -f crawl4ai` でログを観察してください。

### Hermes が SearXNG / Crawl4AI を見つけられない

コンテナ間ホスト名で叩けることを確認:

```bash
docker exec hermes-agent sh -lc 'curl -s http://searxng:8080/healthz'
```

繋がらない場合は、`compose.search.yml` を起動時に渡し忘れている可能性があります（`docker compose ps` で `searxng` / `crawl4ai` が出るか確認）。

### MCP サーバが起動できない / `command not found`

`mcp-searxng` は npm パッケージ、`mcp-crawl4ai` は uvx 配下のため、それぞれ実行系（Node / uv）が `hermes-agent` コンテナ内に必要です。`hermes-agent` のイメージにこれらが含まれていない場合、別のラッパスクリプトや専用 MCP コンテナを用意する必要があります。詳細は各 MCP サーバの README を参照してください。
