#!/bin/sh
set -ex

BASEDIR="$(dirname "$0")";

DOMAIN="$DOMAIN" "$BASEDIR/update.sh";

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs;

# Add NGINX config

sed "s/((DOMAIN))/$DOMAIN/g" "$BASEDIR/site.conf" | \
  sudo tee /etc/nginx/sites-available/root > /dev/null;

sudo ln -s /etc/nginx/sites-available/root /etc/nginx/sites-ready/root;
