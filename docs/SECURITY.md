# セキュリティ

> [English version: SECURITY.en.md](SECURITY.en.md)

このテンプレートは、ローカルLLM用途で安全な既定値になるよう設計されています。

## 目次

- [既定で `127.0.0.1` のみにバインド](#既定で-127001-のみにバインド)
- [Tailscale 経由公開を推奨](#tailscale-経由公開を推奨)
- [パスワード](#パスワード)
- [ワークスペース](#ワークスペース)
- [秘密情報を Git に入れない](#秘密情報を-git-に入れない)
- [Ollama のリスニング設定](#ollama-のリスニング設定)
- [脆弱性報告](#脆弱性報告)

---

## 既定で `127.0.0.1` のみにバインド

```yaml
ports:
  - "127.0.0.1:8787:8787"
  - "127.0.0.1:3001:3001"
  - "127.0.0.1:8642:8642"
```

LAN や公開インターネットに誤って晒すことを防ぎます。
理由が無い限り `0.0.0.0` に変更しないでください。

---

## Tailscale 経由公開を推奨

公開ポートを開けずに自分のtailnet 内のデバイスにだけ見せます。

```bash
./scripts/tailscale-serve.sh
```

これは以下と等価です。

```bash
sudo tailscale serve --bg http://127.0.0.1:8787
```

> [!TIP]
> WebUI のみを公開してください。HUD UI と Agent Gateway はホスト内のみにとどめるのが安全です。

---

## パスワード

`.env` で必ず強いパスワードに変更してください。

```env
HERMES_WEBUI_PASSWORD=change-me-strong-password
```

> [!CAUTION]
> Tailscale 経由とはいえ、tailnet 内の他デバイスや共有メンバからのアクセスはあり得ます。`change-me-strong-password` のままにしないこと。

---

## ワークスペース

既定のマウントは `~/workspace` のみです。

```yaml
volumes:
  - ${HOME}/workspace:/workspace
```

`${HOME}` 全体や `/etc` などをマウントしないでください。エージェントが任意ファイルを読める状態になります。

---

## 秘密情報を Git に入れない

`.gitignore` は最初から以下を無視します。

```gitignore
.env
.env.*
!.env.example
.hermes/
workspace/
```

公開リポジトリに pushする前に必ず確認:

```bash
git status --ignored
git ls-files --error-unmatch .env 2>/dev/null && echo "WARNING: .env is tracked!"
```

---

## Ollama のリスニング設定

Ollama を `0.0.0.0:11434` で listen させる必要がありますが、これは LAN 上の他デバイスからも到達可能になることを意味します。

最低限、ホストファイアウォールで 11434 を制限してください。

```bash
sudo ufw deny 11434/tcp
sudo ufw reload
```

Tailscale を使う場合は、`tailscale0` インターフェース以外からの 11434 を遮断するのが望ましいです。

```bash
sudo iptables -A INPUT -p tcp --dport 11434 ! -i tailscale0 -j DROP
```

---

## 脆弱性報告

セキュリティ上の問題を見つけた場合は、Public な Issue は開かず、リポジトリオーナーへ直接連絡してください。
連絡先: [プロフィール](https://github.com/zephel01) のメール、または GitHub Security Advisory。
