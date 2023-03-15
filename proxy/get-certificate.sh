#!/bin/bash
set -ex

# this script runs as root

if [[ ! -f /etc/letsencrypt/live/all/fullchain.pem ]]; then
  set +x
  while [[ "$(dig +short "$(head -n1 "/var/www/domains.txt")" @8.8.8.8)" != "$(dig +short myip.opendns.com @resolver1.opendns.com)" ]]; do
    if [[ " $* " == *" --immediate "* ]]; then
      exit 1;
    fi;
    echo "DNS not ready - ensure domain DNS points to this instance.";
    sleep 10;
  done;
  set -x
fi;

certbot certonly \
  --non-interactive \
  --agree-tos \
  --register-unsafely-without-email \
  --keep-until-expiring \
  --expand \
  --cert-name all \
  --webroot \
  -w /var/www/http \
  $(< "/var/www/domains.txt" sed 's/[^a-zA-Z0-9.].*//' | grep '.\+' | sort | uniq | sed 's/^/-d /');

# Enable applications

rm /etc/nginx/sites-enabled/* || true;
cp /etc/nginx/sites-ready/* /etc/nginx/sites-enabled;
nginx -s reload;
