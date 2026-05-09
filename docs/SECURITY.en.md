# Security

> [日本語版: SECURITY.md](SECURITY.md)

This template ships with safe defaults for local LLM use.

## Table of contents

- [Bound to `127.0.0.1` by default](#bound-to-127001-by-default)
- [Prefer Tailscale over public ports](#prefer-tailscale-over-public-ports)
- [Password](#password)
- [Workspace](#workspace)
- [Keep secrets out of Git](#keep-secrets-out-of-git)
- [Ollama listening configuration](#ollama-listening-configuration)
- [Reporting vulnerabilities](#reporting-vulnerabilities)

---

## Bound to `127.0.0.1` by default

```yaml
ports:
  - "127.0.0.1:8787:8787"
  - "127.0.0.1:3001:3001"
  - "127.0.0.1:8642:8642"
```

This prevents accidental LAN or public exposure.
Don't change to `0.0.0.0` unless you understand the risk.

---

## Prefer Tailscale over public ports

Expose to your tailnet only — never the open internet:

```bash
./scripts/tailscale-serve.sh
```

This is equivalent to:

```bash
sudo tailscale serve --bg http://127.0.0.1:8787
```

> [!TIP]
> Expose only the WebUI. Keep HUD UI and Agent Gateway host-local.

---

## Password

Always change `HERMES_WEBUI_PASSWORD` in `.env`:

```env
HERMES_WEBUI_PASSWORD=change-me-strong-password
```

> [!CAUTION]
> Even within a tailnet, other devices or shared users may reach the WebUI. Never leave the placeholder password in place.

---

## Workspace

The default mount is only `~/workspace`:

```yaml
volumes:
  - ${HOME}/workspace:/workspace
```

Do not mount your entire `${HOME}` or `/etc`. The agent could read arbitrary files.

---

## Keep secrets out of Git

`.gitignore` excludes secrets by default:

```gitignore
.env
.env.*
!.env.example
.hermes/
workspace/
```

Verify before pushing to a public repo:

```bash
git status --ignored
git ls-files --error-unmatch .env 2>/dev/null && echo "WARNING: .env is tracked!"
```

---

## Ollama listening configuration

Ollama needs `0.0.0.0:11434`, which means it's reachable from your LAN.

At minimum, block 11434 at the host firewall:

```bash
sudo ufw deny 11434/tcp
sudo ufw reload
```

If you use Tailscale, restrict 11434 to the `tailscale0` interface only:

```bash
sudo iptables -A INPUT -p tcp --dport 11434 ! -i tailscale0 -j DROP
```

---

## Reporting vulnerabilities

If you find a security issue, please **do not** open a public Issue.
Contact the repo owner directly via the email on their [profile](https://github.com/zephel01) or open a GitHub Security Advisory.
