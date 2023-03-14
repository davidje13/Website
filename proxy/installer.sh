#!/bin/bash
set -ex

BASEDIR="$(dirname "$0")";

# Install & reset nginx

if ! which nginx; then
  sudo apt-get install -y nginx;
  sudo systemctl stop nginx;
  sudo rm /etc/nginx/sites-enabled/* || true;
fi;

# Configure nginx

sudo rm /etc/nginx/modules-enabled/* || true;
sudo ln -s /usr/share/nginx/modules-available/mod-stream.conf /etc/nginx/modules-enabled/50-mod-stream.conf || true;

install_config "$BASEDIR/config/nginx.conf" /etc/nginx || true;
install_config "$BASEDIR/config/custom.conf" /etc/nginx/conf.d || true;
install_config "$BASEDIR/config/mime.conf" /etc/nginx/conf.d || true;

sudo mkdir -p /etc/nginx/sites-ready; # staging location for sites to enable once SSL is ready

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
sudo chown -R root:www-data /var/www/http;

install_config "$BASEDIR/config/http" /etc/nginx/sites-available || true;
sudo ln -s /etc/nginx/sites-available/http /etc/nginx/sites-ready/http || true;
sudo ln -s /etc/nginx/sites-available/http /etc/nginx/sites-enabled/http || true;

install_config "$BASEDIR/config/certbot-deploy" /etc/letsencrypt/renewal-hooks/deploy 0755 || true;

sudo systemctl start nginx;
