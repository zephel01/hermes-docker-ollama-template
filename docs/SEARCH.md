# Web 検索を有効にする — SearXNG

> [English version: SEARCH.en.md](SEARCH.en.md)

Hermes 単体では Web を検索する能力はありません。本テンプレートでは、`compose.search.yml` を有効にすることで、ローカル完結のメタ検索基盤を立ち上げられます。

## 構成

```text
[ Hermes Agent ]
   │
   │ MCP
   └──→ [ SearXNG ]    : メタ検索（Google/Bing/DuckDuckGo を集約）
                         http://searxng:8080
```

ローカルで動くので、外部の検索 API キーは不要です。

> **ページ本文の取得（extract / crawl）が必要な場合**
> SearXNG はメタ検索専用です。個別ページの本文取得が必要であれば、Firecrawl / Tavily / Exa などの extract プロバイダを別途 `~/.hermes/config.yaml` の `web.extract_backend` で組み合わせてください。詳細は [Hermes 公式ドキュメント](https://hermes-agent.nousresearch.com/docs/user-guide/features/web-search) を参照。

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
| 追加ディスク | 約 200 MB（SearXNG イメージ） |
| 追加メモリ | 約 200 MB |
| 初回起動時間 | 数十秒 |

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

### コンテナ間疎通

```bash
docker exec hermes-agent sh -lc 'curl -s http://searxng:8080/healthz'
```

応答があれば、Hermes Agent から呼べる状態です。

---

## Hermes に MCP として認識させる

`config/mcp.yaml.example` に `searxng` の MCP server 設定を入れています。`setup.sh --with-search` を実行した時点で、`~/.hermes/mcp.yaml` にコピーされているはずです。

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
> MCP サーバはコミュニティ製で、パッケージ名や引数が変わる可能性があります。動かない場合は最新 README を確認してください。
> - [mcp-searxng](https://github.com/ihor-sokoliuk/mcp-searxng)

> [!IMPORTANT]
> MCP の設定にホスト側の絶対パス（例: `/home/USER/...`）を書かないでください。Docker内では存在しません。コマンドは `npx` のようにコンテナ内 PATH で解決できるものを使ってください。

設定後 Agent を再起動:

```bash
docker compose restart hermes-agent
```

---

## プライバシー / セキュリティ

- **検索クエリは外部に出ます**: SearXNG はメタ検索なので、最終的に Google / Bing 等にクエリが飛びます。完全プライベートではありません（ただし SearXNG 側が中継するので、各検索エンジンに対するあなた自身のフットプリントは減ります）。
- **ポートは `127.0.0.1` バインド**: SearXNG (8080) は既定でホストに公開しません（テンプレートで `127.0.0.1:8080:8080` 設定済み）。
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

### Hermes が SearXNG を見つけられない

コンテナ間ホスト名で叩けることを確認:

```bash
docker exec hermes-agent sh -lc 'curl -s http://searxng:8080/healthz'
```

繋がらない場合は、`compose.search.yml` を起動時に渡し忘れている可能性があります（`docker compose ps` で `searxng` が出るか確認）。

### MCP サーバが起動できない / `command not found`

`mcp-searxng` は npm パッケージのため、Node.js が `hermes-agent` コンテナ内に必要です。`hermes-agent` のイメージにこれが含まれていない場合、別のラッパスクリプトや専用 MCP コンテナを用意する必要があります。詳細は MCP サーバの README を参照してください。
