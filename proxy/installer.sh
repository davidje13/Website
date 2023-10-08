#!/bin/bash
set -ex

BASEDIR="$(dirname "$0")";
. "$BASEDIR/../common/utils.sh";

# Configure nginx

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx;

sudo rm /etc/nginx/conf.d/default.conf || true;
install_config "$BASEDIR/config/nginx.conf" /etc/nginx || true;
install_config "$BASEDIR/config/custom.conf" /etc/nginx/conf.d || true;
install_config "$BASEDIR/config/log.conf" /etc/nginx/conf.d || true;
install_config "$BASEDIR/config/mime.conf" /etc/nginx/conf.d || true;
install_config "$BASEDIR/config/badagents.conf" /etc/nginx/conf.d || true;

sudo mkdir -p /etc/systemd/system/nginx.service.d;
install_config "$BASEDIR/config/auto-restart.conf" /etc/systemd/system/nginx.service.d || true;

sudo mkdir -p /etc/nginx/sites-available;
sudo mkdir -p /etc/nginx/sites-ready; # staging location for sites to enable once SSL is ready
sudo mkdir -p /etc/nginx/sites-enabled;

# Prepare SSL

if ! [[ -f /etc/nginx/dhparam.pem ]]; then
  openssl dhparam -out dhparam.pem 2048;
  sudo mv dhparam.pem /etc/nginx/dhparam.pem;
  sudo chmod 0600 /etc/nginx/dhparam.pem;
  sudo chown root:root /etc/nginx/dhparam.pem;
fi;

install_config "$BASEDIR/config/shared-ssl.inc" /etc/nginx/sites-available || true;

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

sudo nginx -t;

sudo systemctl enable nginx; # start at boot
sudo systemctl start nginx;
