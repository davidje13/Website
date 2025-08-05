#!/bin/sh
set -ex

BASEDIR="$(dirname "$0")";
. "$BASEDIR/../common/utils.sh";

# Configure nginx

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx nodejs;

sudo rm /etc/nginx/conf.d/default.conf || true;
install_config "$BASEDIR/config/nginx.conf" /etc/nginx || true;
install_config "$BASEDIR/config/custom.conf" /etc/nginx/conf.d || true;
install_config "$BASEDIR/config/log.conf" /etc/nginx/conf.d || true;
install_config "$BASEDIR/config/mime.conf" /etc/nginx/conf.d || true;
install_config "$BASEDIR/config/proxy.conf" /etc/nginx/conf.d || true;
install_config "$BASEDIR/config/ratelimit.conf" /etc/nginx/conf.d || true;
install_config "$BASEDIR/config/badagents.conf" /etc/nginx/conf.d || true;

sudo mkdir -p /etc/systemd/system/nginx.service.d;
install_config "$BASEDIR/config/auto-restart.conf" /etc/systemd/system/nginx.service.d || true;

sudo mkdir -p /etc/nginx/sites-available;
sudo mkdir -p /etc/nginx/sites-ready; # staging location for sites to enable once SSL is ready
sudo mkdir -p /etc/nginx/sites-enabled;
sudo rm /etc/nginx/sites-enabled/* || true;

# Prepare SSL

if ! [ -f /etc/nginx/dhparam.pem ]; then
  openssl dhparam -out dhparam.pem 2048;
  sudo mv dhparam.pem /etc/nginx/dhparam.pem;
  sudo chmod 0600 /etc/nginx/dhparam.pem;
  sudo chown root:root /etc/nginx/dhparam.pem;
fi;

install_config "$BASEDIR/config/shared-ssl.inc" /etc/nginx/sites-available || true;
install_config "$BASEDIR/config/proxy-common.inc" /etc/nginx/sites-available || true;
install_config "$BASEDIR/config/hacker.inc" /etc/nginx/sites-available || true;

# Prepare for certbot challenge

sudo mkdir -p /var/www/http/.well-known/acme-challenge;
sudo chown -R root:nginx /var/www/http;

sed "s/((DOMAIN))/$DOMAIN/g" "$BASEDIR/config/http.conf" | \
  sudo tee /etc/nginx/sites-available/http > /dev/null;
sudo ln -s /etc/nginx/sites-available/http /etc/nginx/sites-ready/http || true;
sudo ln -s /etc/nginx/sites-available/http /etc/nginx/sites-enabled/http || true;

sed "s/((DOMAIN))/$DOMAIN/g" "$BASEDIR/config/nohost.conf" | \
  sudo tee /etc/nginx/sites-available/nohost > /dev/null;
sudo ln -s /etc/nginx/sites-available/nohost /etc/nginx/sites-ready/nohost || true;
sudo ln -s /etc/nginx/sites-available/nohost /etc/nginx/sites-enabled/nohost || true;

sudo mkdir -p /etc/letsencrypt/renewal-hooks/deploy;
install_config "$BASEDIR/config/certbot-deploy" /etc/letsencrypt/renewal-hooks/deploy 0755 || true;

# generate a "bomb" file to send to attackers

install_web_file() {
  local FILE="$1";
  sudo chown root:nginx "$FILE";
  sudo chmod 0644 "$FILE";
  sudo mv "$FILE" /var/www/http;
}

generate_bomb() {
  local BOMB_TEMP="$HOME";
  local EXTENSION="$1";

  node "$BASEDIR/generate-bomb.mjs" "$EXTENSION" > "$BOMB_TEMP/bomb.$EXTENSION";
  install_web_file "$BOMB_TEMP/bomb.$EXTENSION";

  # (disabled for now because gzip loads full content in memory, and these instances are small)
  if false; then
    node "$BASEDIR/generate-bomb.mjs" "$EXTENSION" --zipped | gzip -nc9 > "$BOMB_TEMP/bomb.$EXTENSION.gz";
  fi;
  # pick up gzipped file if it was added manually
  if [ -f "$BOMB_TEMP/bomb.$EXTENSION.gz" ]; then
    install_web_file "$BOMB_TEMP/bomb.$EXTENSION.gz";
  fi;
}

generate_bomb html;
generate_bomb xml;
generate_bomb json;
generate_bomb yaml;

sudo nginx -t;

sudo systemctl enable nginx; # start at boot
sudo systemctl start nginx;
