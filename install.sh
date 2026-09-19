#!/usr/bin/env bash
# One-time installer: puts `xraywrap` on your PATH and fetches its binaries.
# Usage: sudo ./install.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XRAYWRAP="$ROOT/bin/xraywrap"
LINK="/usr/local/bin/xraywrap"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "This installer needs sudo (writes $LINK and can register a launchd service)." >&2
  echo "Try: sudo $0" >&2
  exit 1
fi

REAL_USER="${SUDO_USER:-$(id -un)}"

if [[ ! -f "$ROOT/etc/config.env" ]]; then
  echo "[install] no etc/config.env yet - copying etc/config.env.example. Edit it with your server details before running 'xraywrap start'."
  sudo -u "$REAL_USER" cp "$ROOT/etc/config.env.example" "$ROOT/etc/config.env"
fi

echo "[install] fetching xray + tun2socks (as $REAL_USER, no root needed for this part)..."
sudo -u "$REAL_USER" "$XRAYWRAP" install

echo "[install] linking $LINK -> $XRAYWRAP"
mkdir -p /usr/local/bin
ln -sf "$XRAYWRAP" "$LINK"

echo
echo "Done. From anywhere, you can now run:"
echo "  xraywrap start           # bring the tunnel up (tun mode, whole machine)"
echo "  xraywrap start socks     # lighter alternative: system SOCKS proxy only"
echo "  xraywrap status"
echo "  xraywrap stop"
echo "  xraywrap doctor"
echo
echo "To also have it start automatically at boot:"
echo "  sudo xraywrap enable"
echo "(not done automatically by this installer - opt in explicitly when you're ready)"
