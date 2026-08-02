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

# iptables -> nftables
# awscli & python3-awscrt = unused
# gnupg = needed to configure external apt sources, but uninstall once this is done (else it keeps running unremovable background processes)
sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y --autoremove iptables awscli python3-awscrt gnupg;

# Install required packages

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  dnsutils \
  certbot \
  nftables;

# Disable extraneous home files which may leak sensitive data

echo 'set viminfo=""' | sudo tee /etc/vim/vimrc.local >/dev/null;
echo 'export LESSHISTFILE=-' | sudo tee /etc/profile.d/lockdown.sh >/dev/null;
rm "$HOME/.viminfo" "$HOME/.lesshst" || true;

# Disable unused local DNS fallbacks

install_config "$BASEDIR/config/60-disable-local-resolve.conf" /etc/systemd/resolved.conf.d || true;

# Configure system

install_config "$BASEDIR/config/20auto-upgrades-local" /etc/apt/apt.conf.d || true;
install_config "$BASEDIR/config/51unattended-upgrades-local" /etc/apt/apt.conf.d || true;
install_config "$BASEDIR/config/50-swappiness.conf" /etc/sysctl.d || true;
install_config "$BASEDIR/config/50-hardening.conf" /etc/sysctl.d || true;
sudo sysctl --system;

install_config "$BASEDIR/config/nftables.conf" /etc 0744 || true;
sudo systemctl enable nftables;
sudo systemctl restart nftables;

# configure zram
# zswap is not available on this base image (`grep -i zswap "/boot/config-$(uname -r)"` shows '# CONFIG_ZSWAP is not set'), so we use zram with no disk swap instead (a-la Fedora):
install_config "$BASEDIR/config/99-zram.conf" /etc/modules-load.d || true;
install_config "$BASEDIR/config/99-zram-params.conf" /etc/modprobe.d || true;
if install_config "$BASEDIR/config/99-zram.rules" /etc/udev/rules.d; then
  echo '/dev/zram0 none swap defaults,discard,pri=100,x-systemd.makefs 0 0' | sudo tee -a /etc/fstab >/dev/null;
fi;

# configure zram for current boot:
if [ ! -e /dev/zram0 ]; then
  sudo modprobe zram num_devices=1;
  sudo zramctl /dev/zram0 --algorithm zstd --size 1G; # we cannot set algorithm parameters (zramctl is too old); in the future we could add '--algorithm-params level=2' for improved speed with minimal loss of compression (also need to update 99-zram.rules)
  echo '512M' | sudo tee /sys/block/zram0/mem_limit >/dev/null;
  sudo mkswap -U clear /dev/zram0;
  sudo swapon --discard --priority 100 /dev/zram0;
fi;
