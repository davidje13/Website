#!/bin/bash
set -ex

BASEDIR="$(dirname "$0")";

. "$BASEDIR/utils.sh";

# Configure sshd

if install_config "$BASEDIR/config/keepalive.conf" /etc/ssh/sshd_config.d; then
  if sudo sshd -t; then
    sudo service sshd reload;
  else
    echo "Keepalive config broke SSHD; reverting";
    sudo rm /etc/ssh/sshd_config.d/keepalive.conf;
  fi;
fi;

# Install required packages

sudo apt-get install -y \
  unattended-upgrades \
  update-notifier-common \
  daemontools \
  certbot;

if ! [[ -d /usr/share/netfilter-persistent ]]; then
  # Answer installer prompts in advance

  echo 'iptables-persistent iptables-persistent/autosave_v4 boolean true' | sudo debconf-set-selections;
  echo 'iptables-persistent iptables-persistent/autosave_v6 boolean true' | sudo debconf-set-selections;

  sudo apt-get install -y iptables-persistent;
fi;

# Remove Canonical adverts

install_config "$BASEDIR/config/motd-news" /etc/default || true;
sudo rm /etc/update-motd.d/10-help-text || true;
sudo systemctl stop ua-timer.timer || true;
sudo systemctl mask ua-timer.timer || true;
sudo systemctl stop ua-timer.service || true;
sudo systemctl mask ua-timer.service || true;
sudo systemctl stop esm-cache.service || true;
sudo systemctl mask esm-cache.service || true;
sudo systemctl stop apt-news.service || true;
sudo systemctl mask apt-news.service || true;
sudo rm -f /etc/apt/apt.conf.d/20apt-esm-hook.conf || true;
sudo rm -f /etc/update-motd.d/88-esm-announce || true;
sudo rm -f /etc/update-motd.d/91-contract-ua-esm-status || true;

# Configure system

install_config "$BASEDIR/config/20auto-upgrades" /etc/apt/apt.conf.d || true;
install_config "$BASEDIR/config/51unattended-upgrades-local" /etc/apt/apt.conf.d || true;
install_config "$BASEDIR/config/50-swappiness.conf" /etc/sysctl.d || true;
install_config "$BASEDIR/config/50-hardening.conf" /etc/sysctl.d || true;
sudo sysctl --system;

# Configure iptables

add_nat_rule -p tcp --dport 80 -j REDIRECT --to-port 8000;
add_nat_rule -p tcp --dport 443 -j REDIRECT --to-port 8443;
sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null;
sudo ip6tables-save | sudo tee /etc/iptables/rules.v6 > /dev/null;
