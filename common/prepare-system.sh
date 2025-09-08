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
  certbot \
  nftables;

# Disable extraneous home files which may leak sensitive data

echo 'set viminfo=""' | sudo tee /etc/vim/vimrc.local >/dev/null;
echo 'export LESSHISTFILE=-' | sudo tee /etc/profile.d/lockdown.sh >/dev/null;
rm "$HOME/.viminfo" "$HOME/.lesshst" || true;

# Configure system

install_config "$BASEDIR/config/20auto-upgrades-local" /etc/apt/apt.conf.d || true;
install_config "$BASEDIR/config/51unattended-upgrades-local" /etc/apt/apt.conf.d || true;
install_config "$BASEDIR/config/50-swappiness.conf" /etc/sysctl.d || true;
install_config "$BASEDIR/config/50-hardening.conf" /etc/sysctl.d || true;
sudo sysctl --system;

install_config "$BASEDIR/config/nftables.conf" /etc 0744 || true;
sudo systemctl enable nftables;
sudo systemctl restart nftables;
