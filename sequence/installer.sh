#!/bin/sh
set -ex

BASEDIR="$(dirname "$0")";
. "$BASEDIR/../common/utils.sh";
SERVICE_PORTS="8080 8081";

# Disable existing update mechanism (if present) to avoid conflicting actions

sudo systemctl disable --now sequence-updater.timer || true;

# Make users

if ! id -u sequence-updater >/dev/null 2>&1; then
  sudo useradd --create-home --user-group sequence-updater;
fi;
if ! id -u sequence-runner >/dev/null 2>&1; then
  sudo useradd --system --user-group sequence-runner;
fi;

# Load dependencies

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs;

# Is this the first install / a fresh install

if ! [ -f /etc/nginx/sites-available/sequence ]; then
  # Load repository

  mkdir -p ~/SequenceDiagram;
  git clone https://github.com/davidje13/SequenceDiagram.git ~/SequenceDiagram;
  cd ~/SequenceDiagram && DISABLE_OPENCOLLECTIVE=1 npm install --omit=dev; cd - > /dev/null;

  # Shutdown existing services if found

  for PORT in $SERVICE_PORTS; do
    sudo systemctl stop "sequence$PORT.service" || true;
  done;
  sudo rm -r /var/www/sequence || true;

  sudo mv ~/SequenceDiagram /var/www/sequence;
fi;

# Install boilerplate

sudo mkdir -p /var/www/sequence/logs;

sudo cp "$BASEDIR/update.sh" /var/www/sequence/update.sh;

sudo chmod -R g-w /var/www/sequence;
sudo chown -R sequence-updater:sequence-runner /var/www/sequence;
sudo chown -R sequence-runner:sequence-runner /var/www/sequence/logs;
sudo chown root:sequence-runner /var/www/sequence/update.sh;
sudo chmod 0544 /var/www/sequence/update.sh;

# Start new services

for PORT in $SERVICE_PORTS; do
  NAME="sequence$PORT.service";
  sed "s/((PORT))/$PORT/g" "$BASEDIR/sequence.service" | \
    sudo tee "/lib/systemd/system/$NAME" > /dev/null;
  sudo chmod 0644 "/lib/systemd/system/$NAME";
  sudo systemctl enable "$NAME";
  sudo systemctl restart "$NAME";
done;

# Configure auto-update

sudo cp "$BASEDIR/sequence-updater.service" "$BASEDIR/sequence-updater.timer" /lib/systemd/system/;
sudo chmod 0644 /lib/systemd/system/sequence-updater.service /lib/systemd/system/sequence-updater.timer;
sudo systemctl enable sequence-updater.timer; # no --now (do not start updater while we are still installing)

# Add NGINX config

sed "s/((DOMAIN))/$DOMAIN/g" "$BASEDIR/site.conf" | \
  sudo tee /etc/nginx/sites-available/sequence > /dev/null;

sudo ln -s /etc/nginx/sites-available/sequence /etc/nginx/sites-ready/sequence;
