#!/bin/bash
# =============================================================================
# Grav host go-live
# =============================================================================
# Run this on the Grav host AFTER:
#   - The HTTP-only Nginx config is deployed and nginx reloaded
#     (yourdomain-http.conf)
#   - DNS has propagated — verify with `dig` first
#
# What it does:
#   1. Runs Certbot to obtain the cert and update the Nginx config to HTTPS
#      (with auto-redirect from 80 -> 443)
#   2. Smoke tests the live site
#
# Usage: sudo bash go-live.sh [domain]
#   Defaults to yourdomain.com; pass your real domain to override.

set -euo pipefail

DOMAIN="${1:-yourdomain.com}"

echo "=== Grav host go-live: $(date -u) ==="
echo "--- $DOMAIN ---"

RESOLVED_IP=$(dig +short "$DOMAIN" | tail -n1)
THIS_IP=$(curl -fsS ifconfig.me || true)
if [ -n "$RESOLVED_IP" ] && [ -n "$THIS_IP" ] && [ "$RESOLVED_IP" != "$THIS_IP" ]; then
  echo "WARNING: $DOMAIN resolves to $RESOLVED_IP but this instance is $THIS_IP."
  echo "DNS may not have fully propagated yet. Certbot's HTTP-01 challenge"
  echo "will fail if traffic isn't reaching this instance."
  read -rp "Continue anyway? [y/N] " CONFIRM
  [[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborting."; exit 1; }
fi

mkdir -p /var/www/certbot

certbot --nginx \
  -d "$DOMAIN" -d "www.$DOMAIN" \
  --redirect \
  --non-interactive --agree-tos \
  -m "admin@$DOMAIN"

nginx -t && systemctl reload nginx
echo "Certbot complete for $DOMAIN — HTTPS is live. Compare"
echo "/etc/nginx/sites-available/$DOMAIN against docker/nginx/ssl-reference.md"
echo "if anything looks off."

HTTP_STATUS=$(curl -sS -o /dev/null -w "%{http_code}" "https://$DOMAIN" || true)
[ -z "$HTTP_STATUS" ] && HTTP_STATUS="000"
if [ "$HTTP_STATUS" = "200" ]; then
  echo "=== Smoke test passed: https://$DOMAIN returned 200 ==="
else
  echo "=== Smoke test returned $HTTP_STATUS for $DOMAIN — check"
  echo "    'docker compose logs' for the grav container ==="
fi

echo "=== Go-live complete: $(date -u) ==="
echo "Grav admin: https://$DOMAIN/admin — set up your admin account."

systemctl list-timers | grep -q certbot && echo "Auto-renewal timer confirmed active." \
  || echo "WARNING: no certbot renewal timer found — check 'systemctl status certbot.timer'"
