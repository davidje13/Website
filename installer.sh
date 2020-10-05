#!/bin/bash
set -ex

BASEDIR="$(dirname "$0")";
DOMAIN="$1";
NODE_VERSION="14";

# Check inputs

if [[ -z "$DOMAIN" ]]; then
  set +x;
  echo "Must specify domain! (e.g. 'davidje13.com')" >&2;
  exit 1;
fi;

if [[ ! -f "$BASEDIR/skip-to-cert" ]]; then

if [[ ! -f "$BASEDIR/env/refacto.env" ]]; then
  set +x;
  echo "Must populate env/refacto.env (copy from env/refacto.template.env)" >&2;
  exit 1;
fi;

# Configure package sources and ensure system is up-to-date

if
  ! which node > /dev/null &&
  ! apt-cache show nodejs | grep "Version: $NODE_VERSION." > /dev/null;
then
  curl -sL "https://deb.nodesource.com/setup_$NODE_VERSION.x" | sudo -E bash -;
  # sudo apt-get update; # done by deb.nodesource.com script
else
  sudo apt-get update;
fi;
sudo apt-get dist-upgrade -y;

if [[ -f /var/run/reboot-required ]]; then
  set +x;
  echo;
  echo;
  echo "Restart required. Restart now then re-run this script.";
  echo "sudo shutdown -r now";
  exit 1;
fi;

# Answer installer prompts in advance

echo 'iptables-persistent iptables-persistent/autosave_v4 boolean true' | sudo debconf-set-selections;
echo 'iptables-persistent iptables-persistent/autosave_v6 boolean true' | sudo debconf-set-selections;

# Install required packages

sudo apt-get install -y \
  unattended-upgrades \
  update-notifier-common \
  iptables-persistent \
  daemontools \
  certbot \
  nginx;
sudo systemctl stop nginx;

# Configure system

install_config() {
  NAME="$1";
  TARGET="$2";
  sudo cp "$BASEDIR/config/$NAME" "$TARGET/$NAME";
  sudo chown root:root "$TARGET/$NAME";
  sudo chmod 0644 "$TARGET/$NAME";
}

install_config motd-news /etc/default;
sudo rm /etc/update-motd.d/10-help-text || true;

install_config 20auto-upgrades /etc/apt/apt.conf.d;
install_config 50unattended-upgrades /etc/apt/apt.conf.d;
install_config 50-swappiness.conf /etc/sysctl.d;
install_config 50-hardening.conf /etc/sysctl.d;
sudo sysctl --system

# Configure iptables

sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8000;
sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443;
sudo ip6tables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8000;
sudo ip6tables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443;
sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null;
sudo ip6tables-save | sudo tee /etc/iptables/rules.v6 > /dev/null;

# Create SSL secret

if ! [[ -f /etc/nginx/dhparam.pem ]]; then
  openssl dhparam -out dhparam.pem 2048;
  sudo mv dhparam.pem /etc/nginx/dhparam.pem;
  sudo chmod 0600 /etc/nginx/dhparam.pem;
  sudo chown root:root /etc/nginx/dhparam.pem;
fi;

# Configure nginx

sudo mkdir -p /var/www/http/.well-known/acme-challenge;
sudo chown -R root:www-data /var/www/http;

sudo rm /etc/nginx/modules-enabled/* || true;
sudo rm /etc/nginx/sites-enabled/* || true;
sudo ln -s /usr/share/nginx/modules-available/mod-stream.conf /etc/nginx/modules-enabled/50-mod-stream.conf;

sudo cp "$BASEDIR/config/nginx.conf" /etc/nginx/nginx.conf;
sudo cp "$BASEDIR/config/custom.conf" /etc/nginx/conf.d/custom.conf;
sudo cp "$BASEDIR/config/mime.conf" /etc/nginx/conf.d/mime.conf;

sudo cp "$BASEDIR/config/shared-ssl.inc" /etc/nginx/sites-available/shared-ssl.inc;

sudo cp "$BASEDIR/config/http" /etc/nginx/sites-available/http;
sudo ln -s /etc/nginx/sites-available/http /etc/nginx/sites-enabled/http;

# Install applications

DOMAIN="$DOMAIN" "$BASEDIR/www/installer.sh";
DOMAIN="$DOMAIN" "$BASEDIR/sequence/installer.sh";
DOMAIN="$DOMAIN" "$BASEDIR/refacto/installer.sh";

fi; # end of skip-to-cert section

# Request SSL certificate

sudo systemctl start nginx;

if [[ ! -f /etc/letsencrypt/live/all/fullchain.pem ]]; then
  SITE_IP="$(dig +short "$DOMAIN" @8.8.8.8)";
  MY_IP="$(dig +short myip.opendns.com @resolver1.opendns.com)";
  if [[ "$SITE_IP" != "$MY_IP" ]]; then
    touch "$BASEDIR/skip-to-cert";
    set +x;
    echo;
    echo;
    echo "Ready to configure certificate.";
    echo "Please change the DNS records for $DOMAIN to use an IP address bound to this instance (or reassign the IP address)";
    echo "(you will probably lose SSH connection when changing IP address - reconnect once done and run this script again to continue)";
    exit 1;
  fi;
fi;

sudo certbot certonly \
  --agree-tos \
  --register-unsafely-without-email \
  --cert-name all \
  --webroot \
  -w /var/www/http \
  -d "$DOMAIN" \
  -d "www.$DOMAIN" \
  -d "retro.$DOMAIN" \
  -d "retros.$DOMAIN" \
  -d "refacto.$DOMAIN" \
  -d "sequence.$DOMAIN";

sudo cp "$BASEDIR/config/certbot-deploy" /etc/letsencrypt/renewal-hooks/deploy/certbot-deploy;
sudo chmod 0755 /etc/letsencrypt/renewal-hooks/deploy/certbot-deploy;

# Enable applications

sudo ln -s /etc/nginx/sites-available/root /etc/nginx/sites-enabled/root;
sudo ln -s /etc/nginx/sites-available/sequence /etc/nginx/sites-enabled/sequence;
sudo ln -s /etc/nginx/sites-available/refacto /etc/nginx/sites-enabled/refacto;

sudo nginx -s reload;

rm "$BASEDIR/skip-to-cert" || true;

set +x;
echo
echo
echo "Done.";

# thanks,
# https://gist.github.com/nrollr/9a39bb636a820fb97eec2ed85e473d38
# https://bjornjohansen.no/redirect-to-https-with-nginx
# http://tumblr.intranation.com/post/766288369/using-nginx-reverse-proxy
# https://certbot.eff.org/
# https://help.ubuntu.com/lts/serverguide/automatic-updates.html
# https://cloud-images.ubuntu.com/locator/ec2/
# https://gist.github.com/alonisser/a2c19f5362c2091ac1e7
# https://www.freedesktop.org/software/systemd/man/systemd.service.html
