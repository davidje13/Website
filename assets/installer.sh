#!/bin/sh
set -ex

if [ -z "$DOMAIN" ]; then
  set +x;
  echo "Must specify DOMAIN environment variable! (e.g. 'davidje13.com')" >&2;
  exit 1;
fi;

BASEDIR="$(dirname "$0")";

# Make users

if ! id -u assets-updater >/dev/null 2>&1; then
  sudo useradd --system --user-group assets-updater;
fi;

# Install boilerplate

sudo mkdir -p /var/www/assets/content;
sudo mkdir -p /var/www/assets/schema;
sudo chmod -R g-w /var/www/assets;
sudo chown root:assets-updater /var/www/assets;
sudo chown -R assets-updater:assets-updater /var/www/assets/content /var/www/assets/schema;

sudo cp "$BASEDIR/update.sh" /var/www/assets/;
sudo chmod 0750 /var/www/assets/update.sh;
sudo chown root:assets-updater /var/www/assets/update.sh;

# Update to first version

sudo -u assets-updater /var/www/assets/update.sh;

# Configure auto-update

sudo cp "$BASEDIR/assets-updater.service" "$BASEDIR/assets-updater.timer" /lib/systemd/system/;
sudo chmod 0644 /lib/systemd/system/assets-updater.service /lib/systemd/system/assets-updater.timer;
sudo systemctl enable assets-updater.timer; # no --now (do not start updater while we are still installing)

# Add NGINX config

sed "s/((DOMAIN))/$DOMAIN/g" "$BASEDIR/global-assets.conf" | \
  sudo tee /etc/nginx/site-extras-available/global-assets > /dev/null;
sudo ln -s /etc/nginx/site-extras-available/global-assets /etc/nginx/site-extras-ready/global-assets;

sed "s/((DOMAIN))/$DOMAIN/g" "$BASEDIR/root-https-assets.conf" | \
  sudo tee /etc/nginx/site-extras-available/root-https-assets > /dev/null;
sudo ln -s /etc/nginx/site-extras-available/root-https-assets /etc/nginx/site-extras-ready/root-https-assets;
