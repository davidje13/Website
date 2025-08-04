#!/bin/sh
set -ex

BASEDIR="$(dirname "$0")";
DOMAIN="$1";

. "$BASEDIR/common/utils.sh";

# Stop previous deploy if still ongoing
kill_process_by_name_fragment 'get-certificate.sh';

# Update packages

set_node_version 24;
set_nginx_repo;
set_mongodb_version '7.0';
sudo apt-get update;
sudo DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y;

if [ -f /var/run/reboot-required ]; then
  set +x;
  echo;
  echo;
  echo "Restart required. Restart now then re-run this script.";
  echo "sudo shutdown -r now";
  exit 1;
fi;

# Check inputs

if [ -z "$DOMAIN" ]; then
  set +x;
  echo "Must specify domain! (e.g. 'davidje13.com')" >&2;
  exit 1;
fi;

# Configure system

"$BASEDIR/common/prepare-system.sh";
sudo rm -f /etc/nginx/sites-ready/* || true;
DOMAIN="$DOMAIN" "$BASEDIR/proxy/installer.sh";

# Install applications

DOMAIN="$DOMAIN" "$BASEDIR/www/installer.sh";
DOMAIN="$DOMAIN" "$BASEDIR/sequence/installer.sh";
DOMAIN="$DOMAIN" "$BASEDIR/refacto/installer.sh";
if [ -d "$HOME/additional-sites" ]; then
  for APP in $(ls "$HOME/additional-sites"); do
    echo "Installing additional site ~/additional-sites/$APP...";
    DOMAIN="$DOMAIN" "$HOME/additional-sites/$APP/installer.sh";
  done;
fi;

# Request SSL certificate

for DOMAIN in $(grep -h 'server_name' /etc/nginx/sites-ready/* | sed -e 's/server_name//' -e 's/;//g'); do
  echo "$DOMAIN";
done | grep -v '^\.' | sort | uniq | sudo tee "/var/www/domains.txt" > /dev/null;

if sudo "$BASEDIR/proxy/get-certificate.sh" --immediate; then
  set +x;
  echo;
  echo;
  echo "Done.";
else
  echo;
  echo;
  printf "Poll until DNS is ready? [y/N]: ";
  read POLL;
  echo;
  if [ "$POLL" = "y" ]; then
    nohup sudo "$BASEDIR/proxy/get-certificate.sh" </dev/null >"$HOME/get-certificate.log" 2>&1 &
    set +x;
    echo "Created background task waiting for $DOMAIN DNS to point to this instance (see ~/get-certificate.log)";
  else
    echo "Not polling. Polling can be started later by re-running this script, or running:"
    echo "sudo $BASEDIR/proxy/get-certificate.sh";
  fi;
fi;

# thanks,
# https://gist.github.com/nrollr/9a39bb636a820fb97eec2ed85e473d38
# https://bjornjohansen.no/redirect-to-https-with-nginx
# http://tumblr.intranation.com/post/766288369/using-nginx-reverse-proxy
# https://certbot.eff.org/
# https://help.ubuntu.com/lts/serverguide/automatic-updates.html
# https://github.com/mvo5/unattended-upgrades
# https://cloud-images.ubuntu.com/locator/ec2/
# https://gist.github.com/alonisser/a2c19f5362c2091ac1e7
# https://www.freedesktop.org/software/systemd/man/systemd.service.html
# https://github.com/nodesource/distributions#manual-installation
# https://www.belle-aurore.com/mike/ubuntu-upgrade-woes/removing-canonicals-ubuntu-advantage-ssh-login-spam/
# https://wiki.archlinux.org/title/Simple_stateful_firewall
# https://www.linode.com/docs/guides/how-to-use-nftables/
# https://wiki.nftables.org/wiki-nftables/index.php/Scripting
# https://wiki.archlinux.org/title/nftables
# https://wiki.nftables.org/wiki-nftables/index.php/Quick_reference-nftables_in_10_minutes
# https://www.nginx.com/blog/rate-limiting-nginx/
# https://www.nginx.com/blog/avoiding-top-10-nginx-configuration-mistakes/
# https://github.com/Skyedra/UnspamifyUbuntu
