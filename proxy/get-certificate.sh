#!/bin/sh
set -ex

# this script runs as root

ANYDOMAIN="$(head -n1 "/var/www/domains.txt")"

is_dns_ready() {
  # fetch own IPv6 address
  MYIP6="$(dig -6 +short myip.opendns.com AAAA @resolver1.opendns.com)";
  DNS_AAAA="$(dig +short "$ANYDOMAIN" AAAA @8.8.8.8)";
  if [ -n "$DNS_AAAA" ] && [ "$DNS_AAAA" = "$MYIP6" ]; then
    echo "IPv6 address $MYIP6 matches domain $ANYDOMAIN";
    return 0;
  fi;

  # only check IPv4 if there is no IPv6 record, since certbot will always prefer IPv6 if present
  if [ -z "$DNS_AAAA" ]; then
    # can also use e.g. $(curl -s4 https://checkip.amazonaws.com)
    MYIP4="$(dig -4 +short myip.opendns.com A @resolver1.opendns.com)";
    DNS_A="$(dig +short "$ANYDOMAIN" A @8.8.8.8)";
    if [ -n "$DNS_A" ] && [ "$DNS_A" = "$MYIP4" ]; then
      echo "IPv4 address $MYIP4 matches domain $ANYDOMAIN (IPv6 not configured)";
      return 0;
    fi;
  fi;

  return 1;
}

reload_nginx() {
  rm /etc/nginx/sites-enabled/* || true;
  cp -P /etc/nginx/sites-ready/* /etc/nginx/sites-enabled;
  nginx -t;
  nginx -s reload;
}

make_self_signed() {
  # https://letsencrypt.org/docs/certificates-for-localhost/#making-and-trusting-your-own-certificates
  DNSID=0;
  cat >/var/www/selfsigned.conf <<EOF ;
[req]
distinguished_name=dn
req_extensions=ext
prompt=no

[dn]
CN=$ANYDOMAIN

[ext]
keyUsage=digitalSignature
extendedKeyUsage=serverAuth
subjectAltName=@alternate_names

[alternate_names]
$(for DOMAIN in cat /var/www/domains.txt; do echo "$DNSID.DNS=$DOMAIN"; DNSID=$((DNSID+1)); done;)
EOF
  openssl req -config /var/www/selfsigned.conf -x509 \
    -out /var/www/selfsigned.crt -keyout /var/www/selfsigned.key \
    -newkey rsa:2048 -nodes -sha256 -days 1;
  rm /var/www/selfsigned.conf;

  cat > /etc/nginx/sites-available/ssl-keys.inc <<EOF ;
# self-signed key
ssl_certificate /var/www/selfsigned.crt;
ssl_certificate_key /var/www/selfsigned.key;
EOF
  echo "Using a self-signed certificate: /var/www/selfsigned.crt" >&2;
}

if ! [ -f /etc/letsencrypt/live/all/fullchain.pem ]; then
  set +x;
  if ! is_dns_ready; then
    if echo " $* " | grep ' --immediate ' >/dev/null; then
      echo "DNS not ready - ensure domain DNS points to this instance.";
      make_self_signed;
      reload_nginx;
      exit 1;
    fi;
  fi;

  sleep 10;
  while ! is_dns_ready; do
    echo "DNS not ready - ensure domain DNS points to this instance.";
    sleep 10;
  done;
  set -x;
fi;

echo "Requesting certificate...";
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

cat > /etc/nginx/sites-available/ssl-keys.inc <<EOF ;
# certbot-generated files
ssl_certificate /etc/letsencrypt/live/all/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/all/privkey.pem;

# Enable OCSP Stapling (reduce overhead of initial connection for clients)
ssl_stapling on;
ssl_stapling_verify on;
ssl_trusted_certificate /etc/letsencrypt/live/all/fullchain.pem;
EOF

# Enable applications
reload_nginx;

# Remove any temporary self-signed certificate (cleanup)
rm /var/www/selfsigned.crt /var/www/selfsigned.key || true;
