#!/bin/sh
set -ex

BASEDIR="$(dirname "$0")";
. "$BASEDIR/../common/utils.sh";
SERVICE_PORTS="8080 8081";

# Disable existing update mechanism (if present) to avoid conflicting actions

sudo systemctl disable --now web-listener-updater.timer || true;
sudo systemctl disable --now web-listener-updater.service || true;

# Make users

if ! id -u web-listener-updater >/dev/null 2>&1; then
  sudo useradd --create-home --user-group web-listener-updater;
fi;
if ! id -u web-listener-runner >/dev/null 2>&1; then
  sudo useradd --create-home --system --user-group web-listener-runner;
  sudo -u web-listener-runner -H sh -c 'mkdir -p ~/.local/bin';
fi;

# Load dependencies

if ! test -f /home/web-listener-runner/.local/bin/web-listener >/dev/null; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs;
  sudo -u web-listener-runner -H npm config set prefix '~/.local/';
fi;
sudo -u web-listener-runner -H npm install -g --ignore-scripts web-listener@1.3.2;

# Install boilerplate

sudo mkdir -p /var/www/web-listener/logs;
sudo mkdir -p /var/www/web-listener/sites;
sudo rm -r /var/www/web-listener/updaters || true;
sudo mkdir /var/www/web-listener/updaters;

for PORT in $SERVICE_PORTS; do
  sudo mkdir -p /var/www/web-listener/logs/log$PORT;
done;

sudo cp "$BASEDIR/update.sh" /var/www/web-listener/update.sh;
sudo cp "$BASEDIR/deploy/deploy.mjs" /var/www/web-listener/deploy.mjs;
sudo cp "$BASEDIR/deploy/public.pem" /var/www/web-listener/public.pem;

sudo chmod -R g-w /var/www/web-listener;
sudo chmod 0744 /var/www/web-listener/update.sh;
sudo chmod 0644 /var/www/web-listener/deploy.mjs;
sudo chmod 0640 /var/www/web-listener/public.pem;
sudo chown root:web-listener-runner \
  /var/www/web-listener \
  /var/www/web-listener/deploy.mjs \
  /var/www/web-listener/public.pem;
sudo chown -R root:web-listener-updater \
  /var/www/web-listener/updaters \
  /var/www/web-listener/update.sh;
sudo chown -R web-listener-updater:web-listener-runner /var/www/web-listener/sites;
sudo chown -R web-listener-runner:web-listener-runner /var/www/web-listener/logs;

install_config "$BASEDIR/50-web-listener-updater" /etc/sudoers.d 0440 || true;

# Update to first version

for SITE in $(ls "$BASEDIR/sites"); do
  if [ -d "$BASEDIR/sites/$SITE" ]; then
    sudo mkdir -p "/var/www/web-listener/updaters/$SITE";
    sudo cp "$BASEDIR/sites/$SITE/update.sh" "/var/www/web-listener/updaters/$SITE/update.sh";
    sudo cp "$BASEDIR/sites/$SITE/public.pem" "/var/www/web-listener/updaters/$SITE/public.pem";
    sudo chmod 0755 "/var/www/web-listener/updaters/$SITE";
    sudo chmod 0654 "/var/www/web-listener/updaters/$SITE/update.sh";
    sudo chmod 0640 "/var/www/web-listener/updaters/$SITE/public.pem";
    sudo chown -R root:web-listener-updater "/var/www/web-listener/updaters/$SITE";

    sed -e "s/((DOMAIN))/$DOMAIN/g" -e "s/((SITE))/$SITE/g" "$BASEDIR/site-template.conf" | \
      sudo tee "/etc/nginx/sites-available/web-listener-$SITE" > /dev/null;
  fi;
done;

sudo /var/www/web-listener/update.sh --force --nostart;

# Start new services

for PORT in $SERVICE_PORTS; do
  NAME="web-listener$PORT.service";
  sed "s/((PORT))/$PORT/g" "$BASEDIR/web-listener.service" | \
    sudo tee "/lib/systemd/system/$NAME" > /dev/null;
  sudo chmod 0644 "/lib/systemd/system/$NAME";
  sudo systemctl enable "$NAME";
  sudo systemctl restart "$NAME";
done;

# Configure auto-update

sudo cp "$BASEDIR/web-listener-updater.service" "$BASEDIR/web-listener-updater.timer" /lib/systemd/system/;
sudo chmod 0644 /lib/systemd/system/web-listener-updater.service /lib/systemd/system/web-listener-updater.timer;
sudo systemctl enable web-listener-updater.service;
sudo systemctl enable web-listener-updater.timer; # no --now (do not start updater while we are still installing)

# Add NGINX config

sed "s/((DOMAIN))/$DOMAIN/g" "$BASEDIR/site.conf" | \
  sudo tee /etc/nginx/sites-available/web-listener > /dev/null;
sudo ln -s /etc/nginx/sites-available/web-listener /etc/nginx/sites-ready/web-listener;

sed "s/((DOMAIN))/$DOMAIN/g" "$BASEDIR/root-https-deploy.conf" | \
  sudo tee /etc/nginx/site-extras-available/root-https-deploy > /dev/null;
sudo ln -s /etc/nginx/site-extras-available/root-https-deploy /etc/nginx/site-extras-ready/root-https-deploy;

for SITE in $(ls "$BASEDIR/sites"); do
  if [ -d "$BASEDIR/sites/$SITE" ]; then
    sudo ln -s "/etc/nginx/sites-available/web-listener-$SITE" "/etc/nginx/sites-ready/web-listener-$SITE";
  fi;
done;
