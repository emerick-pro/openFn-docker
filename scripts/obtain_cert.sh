#!/usr/bin/env bash
# obtain_cert.sh
# Copies the nginx config into /etc/nginx, reloads nginx, and runs certbot to obtain certificates.
# Usage: sudo ./obtain_cert.sh [--staging] --email you@domain.tld --domain openfn.sidainfo.org

set -euo pipefail

STAGING=0
EMAIL=""
DOMAIN="openfn.sidainfo.org"

while [[ $# -gt 0 ]]; do
  case $1 in
    --staging) STAGING=1; shift;;
    --email) EMAIL=$2; shift 2;;
    --domain) DOMAIN=$2; shift 2;;
    *) echo "Unknown argument: $1"; exit 1;;
  esac
done

if [[ -z "$EMAIL" ]]; then
  echo "Please provide an email with --email you@domain.tld"
  exit 1
fi

NGINX_SRC="$(cd "$(dirname "$0")/.." && pwd)/nginx_openfn.conf"

if [[ ! -f "$NGINX_SRC" ]]; then
  echo "Cannot find nginx_openfn.conf in repository root. Expected at: $NGINX_SRC"
  exit 1
fi

SITES_AVAILABLE="/etc/nginx/sites-available"
SITES_ENABLED="/etc/nginx/sites-enabled"

echo "Installing site config to $SITES_AVAILABLE/$DOMAIN"
sudo cp "$NGINX_SRC" "$SITES_AVAILABLE/$DOMAIN"
sudo ln -sf "$SITES_AVAILABLE/$DOMAIN" "$SITES_ENABLED/$DOMAIN"

echo "Testing nginx config"
sudo nginx -t

echo "Reloading nginx"
sudo systemctl reload nginx

if [[ "$STAGING" -eq 1 ]]; then
  STAGE_FLAG="--staging"
else
  STAGE_FLAG=""
fi

echo "Requesting certificate for $DOMAIN"
# Use certbot nginx plugin to automatically configure SSL
sudo certbot --nginx $STAGE_FLAG -d "$DOMAIN" --agree-tos --email "$EMAIL" --non-interactive

echo "Reloading nginx"
sudo nginx -t
sudo systemctl reload nginx

echo "Certificate obtained and nginx reloaded."
