# Web 検索を有効にする — SearXNG

> [English version: SEARCH.en.md](SEARCH.en.md)

Hermes 単体では Web を検索する能力はありません。本テンプレートでは、`docker-compose.yml` に SearXNG を組み込んで、Hermes ネイティブの `web_search` ツールから利用できるようにしています（標準で有効）。

## 構成

```text
[ Hermes Agent ]
   │  web_search ツール（Hermes ネイティブ）
   │
   └──→ [ SearXNG ]    : メタ検索（Google/Bing/DuckDuckGo を集約）
                         http://searxng:8080
```

ローカルで動くので、外部の検索 API キーは不要です。Hermes が組み込みで持っている web tools が SearXNG を直接叩きます。

> **ページ本文の取得（extract / crawl）が必要な場合**
> SearXNG はメタ検索専用です。個別ページの本文取得が必要であれば、Firecrawl / Tavily / Exa などの extract プロバイダを別途 `~/.hermes/config.yaml` の `web.extract_backend` で組み合わせてください。詳細は [Hermes 公式ドキュメント](https://hermes-agent.nousresearch.com/docs/user-guide/features/web-search) を参照。

## 目次

- [必要リソース](#必要リソース)
- [セットアップ](#セットアップ)
- [動作確認](#動作確認)
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

### 1. `setup.sh` を実行

```bash
./scripts/setup.sh
```

これで以下が自動でセットアップされます。

- `searxng/settings.yml` を `searxng/settings.yml.example` から生成（JSON API 有効）
- `.env` に `SEARXNG_SECRET_KEY` を 64文字のランダム値で追記（compose 用）
- **`~/.hermes/.env` に `SEARXNG_URL=http://searxng:8080` を追記**（Hermes Agent 用 ★必須）
- `~/.hermes/config.yaml` に `web.search_backend: "searxng"` を追記（既に書いてあれば保持）

### 2. 起動

```bash
docker compose up -d --build
```

Ollama も Docker 化したい場合は override を並べます:

```bash
docker compose -f docker-compose.yml -f compose.ollama.yml up -d --build
```

### 3. 設定ファイルの中身（手動セットアップする場合）

`setup.sh` を使わず手で書く場合の参考です。

**`~/.hermes/config.yaml`** に追記:

```yaml
web:
  search_backend: "searxng"
  # extract_backend: "firecrawl"   # ページ本文取得が必要なら追加
```

**`~/.hermes/.env`** に追記（★ここがハマりどころ）:

```bash
SEARXNG_URL=http://searxng:8080
```

> [!IMPORTANT]
> `SEARXNG_URL` は **`~/.hermes/.env` から読み込まれます**。
> `docker-compose.yml` の `environment:` ブロックに `SEARXNG_URL` を渡しても **Hermes Agent はそれを無視** します（dotenv 経由で読むため）。
> 設定したのに `Could not reach SearXNG at http://localhost:8888` と出る場合、まず `~/.hermes/.env` を疑ってください。

---

## 動作確認

### SearXNG 単体

```bash
# ホストから
curl 'http://127.0.0.1:8080/search?q=hermes+nous+research&format=json' | head -c 500
```

JSON の `results: [...]` が返ってくれば OK。ブラウザで http://127.0.0.1:8080 を開けば、SearXNG の検索画面が直接使えます。

### Hermes Agent コンテナ内から

`hermes-agent` イメージには `wget` が無いので Python で確認します:

```bash
# (1) ~/.hermes/.env が見えているか
docker exec hermes-agent sh -lc 'cat /home/hermes/.hermes/.env | grep SEARXNG'

# (2) コンテナ間疎通
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

### Hermes Agent からの実行

WebUI（http://127.0.0.1:8787）で **新しいチャット** を開いて:

> 東京の今日の天気を web で検索して

を投げます。`web_search` ツールが SearXNG 経由で呼ばれ、結果が返ってくれば成功。

---

## プライバシー / セキュリティ

- **検索クエリは外部に出ます**: SearXNG はメタ検索なので、最終的に Google / Bing 等にクエリが飛びます。完全プライベートではありません（ただし SearXNG 側が中継するので、各検索エンジンに対するあなた自身のフットプリントは減ります）。
- **完全プライベート寄りにしたい場合**: `searxng/settings.yml` の `engines:` から Google / Bing を外し、DuckDuckGo / Brave / Wikipedia のみにする手があります。
- **ポートは `127.0.0.1` バインド**: SearXNG (8080) は既定でホストに公開しません。
- **`SEARXNG_SECRET_KEY` の取り扱い**: プロジェクトルート `.env` に保存されます。`.env` は `.gitignore` 済み。

---

## トラブルシュート

### `Could not reach SearXNG at http://localhost:8888` と Hermes が言う

`~/.hermes/.env` に `SEARXNG_URL=http://searxng:8080` が **書かれていない**、または **読まれていません**。Hermes は `SEARXNG_URL` 未設定時にデフォルトの `http://localhost:8888` を試します。

```bash
# .env の内容を確認
docker exec hermes-agent sh -lc 'grep SEARXNG /home/hermes/.hermes/.env'

# 無い場合は追記
echo "SEARXNG_URL=http://searxng:8080" >> ~/.hermes/.env
docker compose restart hermes-agent
```

`docker-compose.yml` の `environment:` 経由では効かないので注意。

### `Could not reach SearXNG at http://searxng:8080` と Hermes が言う

URL は正しく読まれた状態で接続失敗 = ネットワーク問題。

```bash
# 同じネットワークにいるか
docker network ls | grep hermes
# → hermes-net （or プロジェクト名_hermes-net）

# 両コンテナとも繋がっているか
docker exec hermes-agent python3 -c "
import urllib.request
print(urllib.request.urlopen('http://searxng:8080/healthz', timeout=5).read())
"
```

### `searxng` コンテナが繰り返し再起動する

`SEARXNG_SECRET_KEY` 未設定が原因です。

```bash
grep SEARXNG_SECRET_KEY .env
```

無ければ `setup.sh` を再実行するか、手動で 32 文字以上のランダム文字列を `.env` に書き足してください。

### `format=json` が 404 / 403 を返す

`searxng/settings.yml` に `formats: [html, json]` が入っているか確認:

```bash
grep -A4 'formats:' searxng/settings.yml
```

無ければ `searxng/settings.yml.example` から再生成してください。

### Hermes が SearXNG を見つけられない

コンテナ間ホスト名で叩けることを確認:

```bash
docker exec hermes-agent python3 -c "
import urllib.request
print(urllib.request.urlopen('http://searxng:8080/healthz', timeout=5).read().decode())
"
```

繋がらない場合は、`searxng` コンテナが起動していない可能性があります（`docker compose ps` で `searxng` が出るか確認）。
