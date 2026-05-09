# FAQ

> [English version: FAQ.en.md](FAQ.en.md)

## 目次

- [Q. macOS / WSL2 で動きますか？](#q-macos--wsl2-で動きますか)
- [Q. NVIDIA GPU は必須ですか？](#q-nvidia-gpu-は必須ですか)
- [Q. どのモデルを最初に試せばいいですか？](#q-どのモデルを最初に試せばいいですか)
- [Q. OpenAI / Claude の API も併用できますか？](#q-openai--claude-の-api-も併用できますか)
- [Q. 複数のモデルを切り替えたい](#q-複数のモデルを切り替えたい)
- [Q. ポート番号を変えたい](#q-ポート番号を変えたい)
- [Q. tailnet にしか繋げたくない](#q-tailnet-にしか繋げたくない)
- [Q. ChatGPT / Claude の Web 版と何が違うの？](#q-chatgpt--claude-の-web-版と何が違うの)
- [Q. データは外部に送信されますか？](#q-データは外部に送信されますか)
- [Q. 既存の `~/.hermes` を残したい](#q-既存の-hermes-を残したい)
- [Q. アップデートはどうやる？](#q-アップデートはどうやる)
- [Q. プロンプトログはどこにある？](#q-プロンプトログはどこにある)
- [Q. Hermes に Web 検索をさせるには？](#q-hermes-に-web-検索をさせるには)
- [Q. SearXNG / Crawl4AI を使うとデータは外に漏れる？](#q-searxng--crawl4ai-を使うとデータは外に漏れる)

---

## Q. macOS / WSL2 で動きますか？

**A.** **macOS は公式サポート対象**です。Apple Silicon / Intel どちらでも動作します。

- Docker は [Docker Desktop](https://www.docker.com/products/docker-desktop/) または [OrbStack](https://orbstack.dev/) を入れてください。`host.docker.internal` はデフォルトで有効です。
- Ollama は Mac アプリ版・Homebrew 版どちらでも可。`launchctl setenv OLLAMA_HOST "0.0.0.0:11434"` または `OLLAMA_HOST=0.0.0.0:11434 brew services start ollama` で listen 設定を入れてください。
- `setup.sh` は OS を自動判定するので、Linux と同じ手順でセットアップできます。

WSL2 は環境差が大きいため、Issue でホストOS / WSLバージョン / Docker Desktop の有無を含めて報告してください。

---

## Q. NVIDIA GPU は必須ですか？

**A.** 必須ではありません。CPU のみでも動きますが、`gemma4:e4b` クラスでも応答速度が大きく低下します。
小型モデル（`qwen2.5:3b`, `phi3:mini` など）であれば CPU のみでも実用範囲です。

---

## Q. どのモデルを最初に試せばいいですか？

**A.** GPU がある場合:

```bash
ollama pull gemma4:e4b
```

CPU のみの場合:

```bash
ollama pull qwen2.5:3b
```

`config.yaml` の `model.default` を実際に使うモデル名と一致させてください。

---

## Q. OpenAI / Claude の API も併用できますか？

**A.** できます。`fallback_providers:` を以下のように設定します。

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

`.env` に `OPENAI_API_KEY` を入れて `docker compose up -d` で再起動します。

---

## Q. 複数のモデルを切り替えたい

**A.** WebUI 上のモデル選択 UI から切り替え可能です。
裏側では同じ Ollama サーバの別モデルを呼び出します。あらかじめ `ollama pull` しておいてください。

---

## Q. ポート番号を変えたい

**A.** `docker-compose.yml` の `ports:` を編集します。

```yaml
ports:
  - "127.0.0.1:18787:8787"
```

`.env` の `HERMES_WEBUI_PORT` も合わせて変更してください。

---

## Q. tailnet にしか繋げたくない

**A.** 既定で `127.0.0.1` バインドなので LAN や外部からは繋がりません。
tailnet からだけ見せたい場合は:

```bash
./scripts/tailscale-serve.sh
```

を実行してください。詳しくは [SECURITY.md](SECURITY.md) を参照。

---

## Q. ChatGPT / Claude の Web 版と何が違うの？

**A.** 主な違い:

- **ローカル実行**: 入力・出力データが手元から出ない
- **モデル選択の自由**: Ollama 経由でオープンウェイトモデルを自由に切替
- **MCP / カスタムツール**: 自前のスクリプトをエージェントから呼べる
- **コスト**: 電気代以外無料

代償として、応答品質はホストの GPU・モデル選択次第です。

---

## Q. データは外部に送信されますか？

**A.** 既定構成では外部に送信されません。

- LLM 推論はホストの Ollama で完結
- WebUI / HUD UI / Agent はすべて `127.0.0.1` バインド
- ただし `fallback_providers` で OpenAI / Claude などを有効にした場合、そちらに送信されます

---

## Q. 既存の `~/.hermes` を残したい

**A.** `setup.sh` は `~/.hermes/config.yaml` を上書きする前にバックアップを取ります。

```text
~/.hermes/config.yaml.bak.20260510-120000
```

不要になったら削除してください。

---

## Q. アップデートはどうやる？

**A.**

```bash
cd hermes-docker-ollama-template
git pull origin main
docker compose pull
docker compose up -d --build
```

WebUI に古い状態が残っている場合は:

```bash
./scripts/reset-webui.sh
```

---

## Q. プロンプトログはどこにある？

**A.** `~/.hermes/` 配下にエージェントの会話履歴やセッション情報が保存されます。
具体的なファイル名は Hermes Agent のバージョンによって変わるため:

```bash
find ~/.hermes -type f -mtime -1
```

で最近更新されたファイルを確認してください。

---

## Q. Hermes に Web 検索をさせるには？

**A.** SearXNG + Crawl4AI のオプション構成を有効にします。

```bash
./scripts/setup.sh --with-search
docker compose -f docker-compose.yml -f compose.search.yml up -d --build
```

SearXNG が検索結果（メタ検索：Google / Bing / DuckDuckGo 等を集約）を、Crawl4AI が個別ページの取得を担当します。詳細は [SEARCH.md](SEARCH.md) を参照。

`--ollama-docker` と組み合わせも可能です:

```bash
docker compose \
  -f docker-compose.yml \
  -f compose.ollama.yml \
  -f compose.search.yml \
  up -d --build
```

---

## Q. SearXNG / Crawl4AI を使うとデータは外に漏れる？

**A.** 一部だけ漏れます。正直に書きます。

- **検索クエリ**: SearXNG はメタ検索なので、最終的に Google / Bing 等にクエリが飛びます。ただし IP / Cookie / User-Agent はあなた個人ではなく SearXNG コンテナのものになるため、追跡されにくくなります。
- **取得したページ内容**: Crawl4AI が読み込んだページの本文はコンテナ内で処理され、外部送信されません。
- **完全プライベート化したい場合**: `searxng/settings.yml` の `engines:` から Google / Bing を外し、DuckDuckGo / Brave / Wikipedia だけにする手があります。それでも各エンジンへのクエリは出ますが、より追跡耐性のある選択肢です。
