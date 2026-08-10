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
