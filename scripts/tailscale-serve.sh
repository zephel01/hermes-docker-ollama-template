#!/usr/bin/env bash
set -euo pipefail

echo "Resetting existing Tailscale Serve config..."
sudo tailscale serve reset || true

echo "Serving Hermes WebUI via Tailscale..."
sudo tailscale serve --bg http://127.0.0.1:8787

echo
echo "Current Tailscale Serve status:"
tailscale serve status
