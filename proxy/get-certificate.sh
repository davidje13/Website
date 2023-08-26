#!/bin/bash
set -ex

# this script runs as root

if [[ ! -f /etc/letsencrypt/live/all/fullchain.pem ]]; then
  set +x;
  while true; do
    # fetch own IP address(es) from AWS internal service
    # (could also use 'dig +short myip.opendns.com AAAA @resolver1.opendns.com' outside AWS)
    MYIP6="$(curl -s http://169.254.169.254/latest/meta-data/ipv6)";
    DNS_AAAA="$(dig +short "$(head -n1 "/var/www/domains.txt")" AAAA @8.8.8.8)";
    if [[ "$DNS_AAAA" == "$MYIP6" ]]; then break; fi;

    # only check IPv4 if there is no IPv6 record, since certbot will always prefer IPv6 if present
    if [[ "$DNS_AAAA" == "" ]]; then
      MYIP4="$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)";
      DNS_A="$(dig +short "$(head -n1 "/var/www/domains.txt")" A @8.8.8.8)";
      if [[ "$DNS_A" == "$MYIP4" ]]; then break; fi;
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
nginx -s reload;
