# コントリビューションガイド / Contributing Guide

> [English version below](#english)

---

## 日本語

### 歓迎するコントリビューション

- バグ報告
- ドキュメントの誤字脱字 / 説明の改善
- 新しいトラブルシュート事例
- 別ディストリビューション（macOS / WSL2 / Fedora 等）の動作報告
- スクリプトの改善
- 多言語化（中国語・韓国語など）

### バグ報告のお願い

Issue を開く前に [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) と [docs/FAQ.md](docs/FAQ.md) を確認してください。

報告には以下を含めてください。

- OS / ディストリビューション / カーネルバージョン
- Docker / Docker Compose のバージョン
- Ollama のバージョン
- `./scripts/check.sh` の出力
- `docker compose logs --tail=200` の出力
- 期待した挙動と実際の挙動

### Pull Request

1. このリポジトリをフォーク
2. ブランチを切る (`git checkout -b feat/your-feature`)
3. 変更を加える
4. 可能ならローカルで `docker compose up -d --build` が通ることを確認
5. PRを開く

#### コミットメッセージ

[Conventional Commits](https://www.conventionalcommits.org/) を推奨します。

```text
feat: add macOS support to setup.sh
fix: correct host.docker.internal mapping for Linux
docs: add WSL2 troubleshooting section
chore: bump hermes-agent image tag
```

### スタイル

- シェルスクリプトは `set -euo pipefail` を必ず先頭に
- YAML は 2スペースインデント
- Markdown は折り返しなし、コードブロックは言語指定あり
- ホストの絶対パスを設定ファイルやドキュメントに直接書かない

### Code of Conduct

互いに敬意を持って接してください。差別的・攻撃的な言動は禁止です。

---

## English

### Contributions we welcome

- Bug reports
- Doc typos and clarity improvements
- New troubleshooting cases
- Reports from other platforms (macOS / WSL2 / Fedora, etc.)
- Script improvements
- Translations (Chinese, Korean, etc.)

### Filing a bug

Please check [docs/TROUBLESHOOTING.en.md](docs/TROUBLESHOOTING.en.md) and [docs/FAQ.en.md](docs/FAQ.en.md) before opening an issue.

Please include:

- OS / distribution / kernel version
- Docker / Docker Compose version
- Ollama version
- Output of `./scripts/check.sh`
- Output of `docker compose logs --tail=200`
- Expected vs. actual behavior

### Pull Requests

1. Fork this repo
2. Create a branch (`git checkout -b feat/your-feature`)
3. Make your changes
4. If possible, verify `docker compose up -d --build` succeeds locally
5. Open a PR

#### Commit messages

We prefer [Conventional Commits](https://www.conventionalcommits.org/):

```text
feat: add macOS support to setup.sh
fix: correct host.docker.internal mapping for Linux
docs: add WSL2 troubleshooting section
chore: bump hermes-agent image tag
```

### Style

- Shell scripts must start with `set -euo pipefail`
- YAML uses 2-space indentation
- Markdown without hard line wraps; code blocks always specify a language
- Never hardcode host absolute paths in configs or docs

### Code of Conduct

Please be respectful. Discriminatory or abusive behavior is not tolerated.
