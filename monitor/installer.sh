#!/bin/sh
set -ex

BASEDIR="$(dirname "$0")";

# Load dependencies

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gcc;

# Build

"$BASEDIR/build.sh";

# Make User

if ! [ -d /var/www/monitor ]; then
  sudo useradd --system --user-group monitor-runner || true;
fi;

# Shutdown existing service if found

sudo systemctl stop stats-monitor.service || true;

# Install

sudo mkdir -p /var/www/monitor/logs;
sudo mv "$BASEDIR/monitor" /var/www/monitor/;

sudo chown root:monitor-runner /var/www/monitor/monitor;
sudo chown -R monitor-runner:monitor-runner /var/www/monitor/logs;
sudo chmod 0550 /var/www/monitor/monitor;

# Create new service

sudo tee "/lib/systemd/system/stats-monitor.service" < "$BASEDIR/stats-monitor.svc" > /dev/null;
sudo chmod 0644 "/lib/systemd/system/stats-monitor.service";
sudo systemctl enable stats-monitor.service;

# Start new service

sudo systemctl start stats-monitor.service;
