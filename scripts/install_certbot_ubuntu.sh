#!/usr/bin/env bash
# install_certbot_ubuntu.sh
# Installs nginx and certbot (Ubuntu/Debian). Run as a user with sudo privileges.
set -euo pipefail

if ! command -v sudo >/dev/null 2>&1; then
  echo "This script requires sudo. Run as a user with sudo privileges."
  exit 1
fi

echo "Installing Nginx and certbot (nginx plugin)..."
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx

echo "Ensuring nginx is running..."
sudo systemctl enable --now nginx

echo "Installation complete."
