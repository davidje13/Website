#!/bin/bash
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

# Install required packages

# update-notifier-common enables automatic restart after unattended-upgrades completes
sudo apt-get install -y \
  unattended-upgrades \
  update-notifier-common \
  daemontools \
  certbot;

sudo apt-get remove -y --autoremove iptables;

# Remove Canonical adverts

install_config "$BASEDIR/config/motd-news" /etc/default || true;
sudo systemctl stop ua-timer.timer || true;
sudo systemctl mask ua-timer.timer || true;
sudo systemctl stop ua-timer.service || true;
sudo systemctl mask ua-timer.service || true;
sudo systemctl stop esm-cache.service || true;
sudo systemctl mask esm-cache.service || true;
sudo systemctl stop apt-news.service || true;
sudo systemctl mask apt-news.service || true;
sudo rm -f /etc/apt/apt.conf.d/20apt-esm-hook.conf || true;
sudo rm -f /etc/update-motd.d/10-help-text || true;
sudo rm -f /etc/update-motd.d/88-esm-announce || true;
sudo rm -f /etc/update-motd.d/91-contract-ua-esm-status || true;
sudo rm /var/log/ubuntu-advantage* || true

# Remove unused AWS services and snap

if which snap >/dev/null; then
  sudo snap remove --purge amazon-ssm-agent || true;
  sudo snap remove --purge lxd || true;
  sudo snap remove --purge core18 || true;
  sudo snap remove --purge core20 || true;
  sudo snap remove --purge snapd || true;
  sudo apt-get remove -y --autoremove snapd;
  sudo rm -rf /snap || true;
  printf 'Package: snapd\nPin: release a=*\nPin-Priority: -10\n' | sudo tee "/etc/apt/preferences.d/snap-pin" >/dev/null;
fi;

# Configure system

install_config "$BASEDIR/config/20auto-upgrades" /etc/apt/apt.conf.d || true;
install_config "$BASEDIR/config/51unattended-upgrades-local" /etc/apt/apt.conf.d || true;
install_config "$BASEDIR/config/50-swappiness.conf" /etc/sysctl.d || true;
install_config "$BASEDIR/config/50-hardening.conf" /etc/sysctl.d || true;
sudo sysctl --system;

install_config "$BASEDIR/config/nftables.conf" /etc 0744 || true;
sudo systemctl enable nftables;
sudo systemctl restart nftables;
