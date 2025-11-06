#!/usr/bin/env bash
# renew_cert_check.sh
# Tests certbot renewal (dry-run) and reloads nginx on success
set -euo pipefail

echo "Running certbot renew --dry-run"
sudo certbot renew --dry-run

# If dry-run succeeds, reload nginx to ensure config picks up renewed certs
sudo nginx -t && sudo systemctl reload nginx

echo "Renewal dry-run succeeded and nginx reloaded (if needed)."
