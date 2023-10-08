#!/bin/bash
set -ex

# this script runs as root

if [[ ! -f /etc/letsencrypt/live/all/fullchain.pem ]]; then
  set +x;
  while true; do
    # fetch own IPv6 address
    MYIP6="$(dig -6 +short myip.opendns.com AAAA @resolver1.opendns.com)";
    DNS_AAAA="$(dig +short "$(head -n1 "/var/www/domains.txt")" AAAA @8.8.8.8)";
    if [[ -n "$DNS_AAAA" && "$DNS_AAAA" == "$MYIP6" ]]; then
      echo "IPv6 address $MYIP6 matches domain - requesting certificate";
      break;
    fi;

    # only check IPv4 if there is no IPv6 record, since certbot will always prefer IPv6 if present
    if [[ -z "$DNS_AAAA" ]]; then
      # can also use e.g. $(curl -s4 https://checkip.amazonaws.com)
      MYIP4="$(dig -4 +short myip.opendns.com A @resolver1.opendns.com)";
      DNS_A="$(dig +short "$(head -n1 "/var/www/domains.txt")" A @8.8.8.8)";
      if [[ -n "$DNS_A" && "$DNS_A" == "$MYIP4" ]]; then
        echo "IPv4 address $MYIP4 matches domain (IPv6 not configured) - requesting certificate";
        break;
      fi;
    fi;

    if [[ " $* " == *" --immediate "* ]]; then
      exit 1;
    fi;
    echo "DNS not ready - ensure domain DNS points to this instance.";
    sleep 10;
  done;
  set -x;
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
  $(< "/var/www/domains.txt" sed 's/[^a-zA-Z0-9.].*//' | grep '.\+' | sed 's/^/-d /');

# Enable applications

rm /etc/nginx/sites-enabled/* || true;
cp -P /etc/nginx/sites-ready/* /etc/nginx/sites-enabled;
nginx -t;
nginx -s reload;
