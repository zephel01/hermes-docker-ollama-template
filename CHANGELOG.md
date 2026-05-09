# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial Docker Compose template for Hermes Agent + WebUI + HUD UI + Ollama
- macOS (Apple Silicon / Intel) support in addition to Linux
- OS auto-detection in `scripts/setup.sh` (portable `sed -i`, OS-specific Ollama hints)
- `compose.ollama.yml` override for "Ollama in Docker" mode (Linux + GPU recommended)
- `config/config.yaml.ollama-docker.example` with `base_url: http://ollama:11434/v1`
- `--ollama-docker` flag for `setup.sh`
- `host.docker.internal:11434` connectivity by default

### Changed
- Renamed `UID` / `GID` env vars to `HOST_UID` / `HOST_GID` to avoid clashing with bash's
  read-only `UID` builtin (also helps macOS where the default user is `501:20`, not `1000:1000`).
- Custom OpenAI-compatible endpoint configuration for Ollama
- `model_catalog.enabled: false` to suppress stale provider entries
- `tmpfs` mount for `hermes-webui`
- Custom `Dockerfile` for `hermes-hudui`
- `scripts/setup.sh` — bootstrap host environment
- `scripts/check.sh` — verify Ollama, Docker, and WebUI connectivity
- `scripts/reset-webui.sh` — back up and rebuild WebUI state
- `scripts/tailscale-serve.sh` — expose WebUI via Tailscale only
- Bilingual documentation (Japanese / English)
  - `README.md` / `README.en.md`
  - `docs/INSTALL.md` / `docs/INSTALL.en.md`
  - `docs/ARCHITECTURE.md` / `docs/ARCHITECTURE.en.md`
  - `docs/TROUBLESHOOTING.md` / `docs/TROUBLESHOOTING.en.md`
  - `docs/SECURITY.md` / `docs/SECURITY.en.md`
  - `docs/FAQ.md` / `docs/FAQ.en.md`
- GitHub issue and PR templates under `.github/`

[Unreleased]: https://github.com/zephel01/hermes-docker-ollama-template/commits/main
