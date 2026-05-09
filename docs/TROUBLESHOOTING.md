# トラブルシュート

> [English version: TROUBLESHOOTING.en.md](TROUBLESHOOTING.en.md)

まず最初に [`./scripts/check.sh`](../scripts/check.sh) を実行して、どこで切れているかを切り分けてください。

## 目次

- [`Connection error` が出る](#connection-error-が出る)
- [`Provider 'custom:gemma4' is set but no API key was found`](#provider-customgemma4-is-set-but-no-api-key-was-found)
- [WebUI に Gemini / GPT / DeepSeek が出る](#webui-に-gemini--gpt--deepseek-が出る)
- [`/tmp/hermeswebui_root_env.txt: Permission denied`](#tmphermeswebui_root_envtxt-permission-denied)
- [`HERMES_WEBUI_STATE_DIR not set`](#hermes_webui_state_dir-not-set)
- [`mkdir: cannot create directory '/home/...': Permission denied`](#mkdir-cannot-create-directory-home-permission-denied)
- [MCP server で `missing executable uvx`](#mcp-server-で-missing-executable-uvx)
- [`hermes-hudui` が起動しない](#hermes-hudui-が起動しない)
- [LLM の応答が極端に遅い](#llm-の応答が極端に遅い)
- [WebUI からログインできない](#webui-からログインできない)
- [SearXNG 関連](#searxng-関連)

---

## `Connection error` が出る

WebUI のチャットで「Connection error」と表示されたら、まずログを確認します。

```bash
docker compose logs --tail=120 hermes-webui
```

以下のような出力があれば設定ミスです。

```text
Endpoint: http://127.0.0.1:11434/v1
```

正しい値:

```text
http://host.docker.internal:11434/v1
```

コンテナ内から到達性を確認します。

```bash
docker exec -it hermes-webui bash -lc \
  'curl -s http://host.docker.internal:11434/v1/models | head'
```

繋がらない場合は、ホスト側の Ollama が `0.0.0.0:11434` で listen しているか確認してください。

Linux:

```bash
sudo systemctl status ollama
ss -tlnp | grep 11434
```

macOS:

```bash
launchctl getenv OLLAMA_HOST            # Mac アプリ版
ps aux | grep ollama
lsof -nP -iTCP:11434 -sTCP:LISTEN
```

`*:11434 (LISTEN)` のように `0.0.0.0` 相当で listen していればOK、`127.0.0.1:11434 (LISTEN)` だけになっていたら設定が反映されていません。

---

## `Provider 'custom:gemma4' is set but no API key was found`

モデル名の `:` がプロバイダ名としてパースされている状態です。

設定を **Custom endpoint** にし直してください。

```yaml
model:
  provider: custom
  default: "gemma4:e4b"
  base_url: "http://host.docker.internal:11434/v1"
  api_key: ""
```

その後で WebUI 状態を初期化:

```bash
./scripts/reset-webui.sh
```

---

## WebUI に Gemini / GPT / DeepSeek が出る

`model_catalog` が有効になっている可能性があります。

```yaml
model_catalog:
  enabled: false
```

このあと WebUI の状態キャッシュを消します。

```bash
./scripts/reset-webui.sh
```

---

## `/tmp/hermeswebui_root_env.txt: Permission denied`

`hermes-webui` コンテナの `/tmp` が書き込み不可になっています。
`docker-compose.yml` に以下があることを確認してください。

```yaml
hermes-webui:
  ...
  tmpfs:
    - /tmp:rw,nosuid,nodev,mode=1777
```

---

## `HERMES_WEBUI_STATE_DIR not set`

`.env` に必須の環境変数が無い、または空のまま渡っています。

```env
HERMES_WEBUI_STATE_DIR=/home/hermeswebui/.hermes/webui
```

> [!IMPORTANT]
> ホスト側の絶対パス（例: `/home/zephel01/.hermes/webui`）を書かないでください。コンテナ内ユーザーには書き込み権限がありません。

---

## `mkdir: cannot create directory '/home/...': Permission denied`

ホスト側のパスを `.env` に書いてしまっているケースです。

NG:

```env
HERMES_WEBUI_STATE_DIR=/home/zephel01/.hermes/webui
```

OK:

```env
HERMES_WEBUI_STATE_DIR=/home/hermeswebui/.hermes/webui
```

---

## MCP server で `missing executable uvx`

```text
missing executable '/home/USER/works/hermes/.venv/bin/uvx'
```

これは `~/.hermes/mcp.yaml` などにホストの絶対パスが残っているためです。

切り分けの順序:

1. MCP 設定をいったん無効化する
2. `docker compose restart` する
3. 通常チャットで応答が返るのを確認する
4. その上で必要な MCP だけ有効化する（`docker exec` 経由でコンテナ内パスを確認しながら）

---

## `hermes-hudui` が起動しない

公式リポジトリの構成変更で `pyproject.toml` などのパスが変わっている可能性があります。
このテンプレートの `hermes-hudui/Dockerfile` は最新コミットを前提としているため、別の commit を使う場合は `Dockerfile` の `COPY` 行を調整してください。

```bash
docker compose logs --tail=120 hermes-hudui
docker compose build --no-cache hermes-hudui
docker compose up -d hermes-hudui
```

---

## LLM の応答が極端に遅い

- ホストの GPU が認識されているか確認: `nvidia-smi`
- Ollama が GPU を使っているか確認: `ollama ps`
- モデルが大きすぎる場合は `gemma4:e4b` などの軽量モデルに切り替える

```bash
ollama pull qwen2.5:3b
```

`config.yaml` の `model.default` を更新後、`docker compose restart` してください。

---

## WebUI からログインできない

`.env` の `HERMES_WEBUI_PASSWORD` を変更したのに古いパスワードを入れている可能性があります。
ブラウザのキャッシュ／Cookie をクリアして、もう一度 `.env` の値で入り直してください。

それでもダメな場合は WebUI 状態をリセットします。

```bash
./scripts/reset-webui.sh
```

---

## SearXNG 関連

検索基盤を有効にしている場合（`compose.search.yml`）の典型的な詰まりは [SEARCH.md](SEARCH.md) のトラブルシュートに集約しています。よくあるもの:

- `searxng` コンテナが再起動を繰り返す → `SEARXNG_SECRET_KEY` 未設定
- `format=json` が 404 / 403 → `searxng/settings.yml` の `formats: [html, json]` 不足
- Hermes から SearXNG に到達できない → `compose.search.yml` を起動コマンドに渡し忘れ
- MCP サーバが `command not found` → `mcp-searxng` (npm) の実行系（Node.js）がコンテナ内に必要

詳しい確認手順は [SEARCH.md](SEARCH.md) を参照してください。
