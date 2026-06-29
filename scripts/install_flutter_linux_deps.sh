#!/usr/bin/env bash
# Install system packages required to build/run Flutter on Linux desktop.
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run with sudo:"
  echo "  sudo ./scripts/install_flutter_linux_deps.sh"
  exit 1
fi

apt-get update
apt-get install -y \
  libgtk-3-dev \
  libwebp-dev \
  libsecret-1-dev \
  libayatana-appindicator3-dev \
  clang \
  cmake \
  ninja-build \
  pkg-config

echo ""
echo "Done. Rebuild Flutter:"
echo "  cd flutter && flutter clean && flutter run -d linux"
