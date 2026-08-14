# SSL reference

You do NOT deploy this directly. Certbot (via the Nginx plugin, run in
`docker/scripts/go-live.sh`) edits `/etc/nginx/sites-available/yourdomain.com`
in place and adds an HTTPS block equivalent to what's below. This file exists
so you can compare against what Certbot actually produced, and as a manual
fallback if you ever need to rebuild an HTTPS block by hand (e.g. restoring
from a backup instance).

The certificate lives under Certbot's default layout:

```
/etc/letsencrypt/live/yourdomain.com/{fullchain,privkey}.pem
```

## yourdomain.com (Grav)

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name yourdomain.com www.yourdomain.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name yourdomain.com www.yourdomain.com;

    ssl_certificate     /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparam.pem;

    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains" always;

    location / {
        proxy_pass http://127.0.0.1:2380;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        client_max_body_size 50m;
    }
}
```

## Making the apex canonical

What Certbot leaves you with above is **not** finished. Both hostnames sit
in one `server_name` and both return 200, and `--redirect` only upgrades
HTTP to HTTPS while preserving `$host` — so nothing ever picks a winner
between `yourdomain.com` and `www.yourdomain.com`. Identical content on two
hostnames splits inbound links and reads as duplicate content to search
engines, and any analytics property you point at one hostname quietly
misses traffic to the other.

Pick one and redirect the other. The apex is the natural choice here: the
DNS module creates the A record on the apex and `www` only as a CNAME back
to it. Replace the two blocks above with these three:

```nginx
# 1. Apex over HTTPS — the only block that actually serves the site.
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name yourdomain.com;

    ssl_certificate     /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparam.pem;

    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains" always;

    location / {
        proxy_pass http://127.0.0.1:2380;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        client_max_body_size 50m;
    }
}

# 2. www over HTTPS — redirect only. It still needs the cert: the client
#    completes the TLS handshake against www BEFORE it can be told to go
#    elsewhere, so a redirect-only block without a valid cert produces a
#    browser warning instead of a redirect. go-live.sh already requests a
#    cert covering both names, so nothing extra is needed here.
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name www.yourdomain.com;

    ssl_certificate     /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparam.pem;

    return 301 https://yourdomain.com$request_uri;
}

# 3. Both names over plain HTTP. www goes straight to the apex over HTTPS
#    in one hop rather than bouncing through www:443 first.
server {
    listen 80;
    listen [::]:80;
    server_name yourdomain.com www.yourdomain.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://yourdomain.com$request_uri;
    }
}
```

Then `sudo nginx -t && sudo systemctl reload nginx` — the `-t` is what stops
a typo from taking the site down.

Verify all four entry points. The apex returns 200; the other three return
301 to `https://yourdomain.com/`:

```bash
curl -sI https://yourdomain.com     | grep -iE "^HTTP|^location"
curl -sI https://www.yourdomain.com | grep -iE "^HTTP|^location"
curl -sI http://www.yourdomain.com  | grep -iE "^HTTP|^location"
curl -sI http://yourdomain.com      | grep -iE "^HTTP|^location"
```

Always re-test with a real path too, not just the bare hostname — a
redirect that drops `$request_uri` still passes the test above while
silently sending every deep link to the homepage:

```bash
curl -sI https://www.yourdomain.com/some/real/page | grep -i location
```

### Grav also needs to be told

Grav builds absolute URLs from what PHP sees, and behind this proxy it sees
plain HTTP on `127.0.0.1:2380`. nginx sends `X-Forwarded-Proto https`, but
Grav does not trust it by default, so `<link rel="canonical">` comes out as
`http://` — pointing at a URL that immediately redirects, which is exactly
what a canonical should not do. Pin it in `user/config/system.yaml`:

```yaml
custom_base_url: 'https://yourdomain.com'
```

This affects every absolute URL Grav generates, not just the canonical tag,
so check navigation and any feed or sitemap output after changing it.
