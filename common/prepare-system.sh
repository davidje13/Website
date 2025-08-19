#!/bin/sh
set -ex

BASEDIR="$(dirname "$0")";

. "$BASEDIR/utils.sh";

# Configure sshd

if install_config "$BASEDIR/config/keepalive.conf" /etc/ssh/sshd_config.d; then
  if sudo sshd -t; then
    sudo service sshd reload;
  else
    echo 'Keepalive config broke SSHD; reverting' >&2;
    sudo rm /etc/ssh/sshd_config.d/keepalive.conf;
  fi;
fi;

# Remove conflicting packages and unused AWS services

sudo apt-get remove -y --autoremove iptables awscli python3-awscrt;

# Install required packages

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  dnsutils \
  daemontools \
  certbot \
  nftables;

# Configure system

install_config "$BASEDIR/config/20auto-upgrades-local" /etc/apt/apt.conf.d || true;
install_config "$BASEDIR/config/51unattended-upgrades-local" /etc/apt/apt.conf.d || true;
install_config "$BASEDIR/config/50-swappiness.conf" /etc/sysctl.d || true;
install_config "$BASEDIR/config/50-hardening.conf" /etc/sysctl.d || true;
sudo sysctl --system;

install_config "$BASEDIR/config/nftables.conf" /etc 0744 || true;
sudo systemctl enable nftables;
sudo systemctl restart nftables;

# Fix warning due to old version of cloud-init on Debian: https://github.com/canonical/cloud-init/issues/6405
sudo chmod 0600 /etc/netplan/50-cloud-init.yaml;

# Disable cloud-init for subsequent boots
# (fixes issue where all SSH host keys are regenerated on restart when metadata endpoint is disabled - similar to https://github.com/canonical/cloud-init/issues/6270)
sudo touch /etc/cloud/cloud-init.disabled;
