# インストールガイド

> [English version: INSTALL.en.md](INSTALL.en.md)

このドキュメントは [README.md](../README.md) のクイックスタートをより詳しく説明したものです。

## 目次

- [前提環境](#前提環境)
- [1. Docker のインストール](#1-docker-のインストール)
- [2. Ollama のインストール](#2-ollama-のインストール)
- [3. Ollama を Docker から見えるようにする](#3-ollama-を-docker-から見えるようにする)
- [4. このテンプレートのセットアップ](#4-このテンプレートのセットアップ)
- [5. 起動と動作確認](#5-起動と動作確認)
- [6. アンインストール](#6-アンインストール)

---

## 前提環境

| 項目 | 推奨 |
|---|---|
| OS | Linux (Ubuntu 22.04+ / Debian 12+ / Arch / Fedora 39+) または **macOS 13+ (Apple Silicon / Intel)** |
| CPU | x86_64 または arm64 (Apple Silicon)。GPU がない場合は小型モデル推奨 |
| RAM | 16 GB 以上推奨 |
| ストレージ | 30 GB 以上の空き |
| ネットワーク | Tailscale 推奨 |

---

## 1. Docker のインストール

### Linux (Ubuntu / Debian)

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"
newgrp docker
docker compose version
```

### Linux (Arch)

```bash
sudo pacman -S docker docker-compose
sudo systemctl enable --now docker.service
sudo usermod -aG docker "$USER"
```

### macOS

[Docker Desktop](https://www.docker.com/products/docker-desktop/) または [OrbStack](https://orbstack.dev/) を入れます。Apple Silicon では OrbStack の方が軽量です。

```bash
# Homebrew の場合
brew install --cask docker          # Docker Desktop
# あるいは
brew install --cask orbstack        # OrbStack
```

確認:

```bash
docker run --rm hello-world
docker compose version
```

> [!TIP]
> macOS の Docker Desktop / OrbStack は `host.docker.internal` がデフォルトで有効です。追加設定不要。

---

## 2. Ollama のインストール

### Linux

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### macOS

[Mac アプリ版 Ollama](https://ollama.com/download) を入れるか、Homebrew で:

```bash
brew install ollama
```

### モデルの取得（共通）

```bash
ollama pull gemma4:e4b
ollama list
```

任意のモデルでOKですが、`config/config.yaml.example` の `default` と一致させてください。

---

## 3. Ollama を Docker から見えるようにする

> [!IMPORTANT]
> Docker コンテナから `127.0.0.1:11434` はホストに繋がりません。Ollama を `0.0.0.0:11434` で listen させてください。

### Linux (systemd)

```bash
sudo systemctl edit ollama
```

エディタで以下を追記:

```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
```

反映:

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
sudo systemctl status ollama
curl http://127.0.0.1:11434/api/tags
```

### macOS（Mac アプリ版）

```bash
launchctl setenv OLLAMA_HOST "0.0.0.0:11434"
```

メニューバーから Ollama を Quit → 再起動。

```bash
curl http://127.0.0.1:11434/api/tags
```

> [!NOTE]
> `launchctl setenv` は再起動で消えます。永続化する場合は `~/Library/LaunchAgents/` に plist を置くか、Mac アプリの設定 UI（Ollama 0.5+ では設定画面で `OLLAMA_HOST` を指定可能）を使ってください。

### macOS (Homebrew)

```bash
brew services stop ollama
OLLAMA_HOST=0.0.0.0:11434 brew services start ollama
curl http://127.0.0.1:11434/api/tags
```

### ファイアウォール

> [!WARNING]
> `0.0.0.0` はLAN内からも見える状態になります。Tailscale を併用するか、以下でブロックしてください。

Linux:

```bash
sudo ufw deny 11434/tcp
sudo ufw reload
```

macOS:

```bash
# システム設定 → ネットワーク → ファイアウォール
# または Little Snitch / LuLu などで 11434 を制限
```

---

## 4. このテンプレートのセットアップ

```bash
git clone https://github.com/YOUR_NAME/hermes-docker-ollama-template.git
cd hermes-docker-ollama-template

chmod +x scripts/*.sh
./scripts/setup.sh
```

`setup.sh` は OS を自動判定して、Linux / macOS どちらでも動作します。次のことを行います。

1. 必須コマンドの存在確認 (`git`, `docker`, `curl`)
2. `~/.hermes` と `~/workspace` を作成
3. `.env.example` から `.env` を生成、UID / GID を埋める
4. `config/config.yaml.example` を `~/.hermes/config.yaml` にコピー（既存はバックアップ）
5. パーミッション修正（macOS では基本的に不要なので best-effort）
6. Ollama 到達性を確認（OS別に修正手順を表示）
7. `hermes-webui` と `hermes-hudui` のソースを git clone（既存はスキップ）

> [!TIP]
> `.env` の `HERMES_WEBUI_PASSWORD` は必ず変更してください。

> [!NOTE]
> `HOST_UID` / `HOST_GID` は `setup.sh` が `id -u` / `id -g` から自動で埋めます。
> macOS の通常ユーザーは `501:20`、Linux の最初のユーザーは `1000:1000` になることが多く、`.env.example` のプレースホルダ値（1000）のままだと bind mount のオーナーが合わない場合があります。`setup.sh` を必ず実行してください。

### Ollama を Docker 化したい場合（Linux + GPU 推奨）

ホスト Ollama ではなくコンテナとして起動する構成も用意しています。

```bash
./scripts/setup.sh --ollama-docker
docker compose -f docker-compose.yml -f compose.ollama.yml up -d --build

# 初回はモデルをコンテナに pull
docker exec -it ollama ollama pull gemma4:e4b
```

NVIDIA GPU を使う場合は `compose.ollama.yml` 内の `deploy.resources.reservations.devices` ブロックをアンコメントしてください。事前に NVIDIA Container Toolkit のインストールが必要です。

> [!WARNING]
> macOS で `--ollama-docker` を使うと CPU 推論になります（Docker Desktop が Apple Silicon GPU をパススルーできないため）。Mac ではホスト Ollama 構成を強く推奨します。

### Web 検索を有効にしたい場合（SearXNG）

```bash
./scripts/setup.sh --with-search
docker compose -f docker-compose.yml -f compose.search.yml up -d --build
```

`setup.sh --with-search` は次を自動で行います。

- `searxng/settings.yml` を生成（`formats: [html, json]` 有効）
- `.env` に 64文字の `SEARXNG_SECRET_KEY` を追記
- `~/.hermes/mcp.yaml` に SearXNG 用 MCP エントリをコピー

`--ollama-docker` と組み合わせ可能です:

```bash
docker compose \
  -f docker-compose.yml \
  -f compose.ollama.yml \
  -f compose.search.yml \
  up -d --build
```

詳細は [SEARCH.md](SEARCH.md) を参照してください。

---

## 5. 起動と動作確認

```bash
docker compose up -d --build
docker compose ps
./scripts/check.sh
```

ブラウザで以下を開きます。

- WebUI: http://127.0.0.1:8787
- HUD UI: http://127.0.0.1:3001

ログイン後、`gemma4:e4b` などにメッセージを投げて応答が返ってくれば成功です。

エラーが出た場合は [TROUBLESHOOTING.md](TROUBLESHOOTING.md) を参照してください。

---

## 6. アンインストール

```bash
cd hermes-docker-ollama-template
docker compose down -v
```

データを完全に消したい場合:

```bash
rm -rf ~/.hermes ~/workspace
docker volume prune -f
docker image rm nousresearch/hermes-agent:latest || true
```

> [!CAUTION]
> `~/.hermes` には会話履歴・メモリ・APIキーが含まれることがあります。削除前に必ずバックアップしてください。
