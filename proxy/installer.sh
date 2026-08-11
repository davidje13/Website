#!/bin/sh
set -ex

BASEDIR="$(dirname "$0")";
. "$BASEDIR/../common/utils.sh";

# Configure nginx

sudo DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=5 install -y nginx nodejs logrotate python3-venv;

sudo rm /etc/nginx/conf.d/default.conf || true;
install_config "$BASEDIR/config/nginx.conf" /etc/nginx || true;
install_config "$BASEDIR/config/custom.conf" /etc/nginx/conf.d || true;
install_config "$BASEDIR/config/log.conf" /etc/nginx/conf.d || true;
install_config "$BASEDIR/config/mime.conf" /etc/nginx/conf.d || true;
install_config "$BASEDIR/config/proxy.conf" /etc/nginx/conf.d || true;
install_config "$BASEDIR/config/ratelimit.conf" /etc/nginx/conf.d || true;
install_config "$BASEDIR/config/badagents.conf" /etc/nginx/conf.d || true;
install_config "$BASEDIR/config/logrotate/nginx" /etc/logrotate.d || true;

sudo mkdir -p /etc/systemd/system/nginx.service.d;
install_config "$BASEDIR/config/auto-restart.conf" /etc/systemd/system/nginx.service.d || true;

sudo mkdir -p /etc/nginx/sites-available;
sudo mkdir -p /etc/nginx/sites-ready; # staging location for sites to enable once SSL is ready
sudo mkdir -p /etc/nginx/sites-enabled;
sudo mkdir -p /etc/nginx/site-extras-available;
sudo mkdir -p /etc/nginx/site-extras-ready;
sudo mkdir -p /etc/nginx/site-extras-enabled; # files to include in the root domain config
sudo rm /etc/nginx/sites-enabled/* || true;
sudo rm /etc/nginx/site-extras-enabled/* || true;

# Prepare SSL

if ! [ -f /etc/nginx/dhparam.pem ]; then
  openssl dhparam -out dhparam.pem 2048;
  sudo mv dhparam.pem /etc/nginx/dhparam.pem;
  sudo chmod 0600 /etc/nginx/dhparam.pem;
  sudo chown root:root /etc/nginx/dhparam.pem;
fi;

install_config "$BASEDIR/config/shared-ssl.inc" /etc/nginx/sites-available || true;
install_config "$BASEDIR/config/proxy-common.inc" /etc/nginx/sites-available || true;
install_config "$BASEDIR/config/hacker.inc" /etc/nginx/sites-available || true;

# Install certbot

sudo systemctl disable --now certbot-update.timer || true;
if ! id -u certbot-runner >/dev/null 2>&1; then
  sudo useradd --system --user-group certbot-runner;
fi;
install_config "$BASEDIR/config/50-certbot-runner" /etc/sudoers.d 0440 || true;

sudo mkdir -p /opt/certbot/.cache /etc/letsencrypt /var/log/letsencrypt /var/lib/letsencrypt;
sudo chmod 0700 /var/log/letsencrypt;
sudo chown -R certbot-runner:certbot-runner /opt/certbot /etc/letsencrypt /var/log/letsencrypt /var/lib/letsencrypt;
sudo -u certbot-runner python3 -m venv /opt/certbot/;
sudo -u certbot-runner XDG_CACHE_HOME=/opt/certbot/.cache /opt/certbot/bin/pip install --upgrade pip;
sudo -u certbot-runner XDG_CACHE_HOME=/opt/certbot/.cache /opt/certbot/bin/pip install --upgrade --uploaded-prior-to=P30D certbot certbot-dns-route53;

if ! [ -f /opt/certbot/aws.config ] && ! [ -f /etc/letsencrypt/live/wild/fullchain.pem ]; then
  set +x;
  echo >&2;
  echo "An AWS access key and secret are needed for certbot to manage DNS records." >&2;
  echo "Create a non-console IAM user with the following policy:" >&2;
  echo >&2;
  sed "s/((DOMAIN))/$DOMAIN/g" "$BASEDIR/config/dns-policy.json" >&2;
  echo >&2;
  echo "Create an access key for the user and enter it below." >&2;
  echo >&2;
  echo "If skipped, the https certificate will not be a wildcard certificate, and will be limited to 25 domains." >&2;
  printf "Enter the aws_access_key_id (or blank): " >&2;
  read ACCESS_KEY;
  echo >&2;
  if [ -n "$ACCESS_KEY" ]; then
    printf "Enter the aws_secret_access_key: " >&2;
    read SECRET_ACCESS_KEY;
    echo >&2;
    printf "[default]\naws_access_key_id=%s\naws_secret_access_key=%s\n" "$ACCESS_KEY" "$SECRET_ACCESS_KEY" | sudo tee /opt/certbot/aws.config >/dev/null;
    set -x;
    unset ACCESS_KEY SECRET_ACCESS_KEY;
    sudo chmod 0400 /opt/certbot/aws.config;
    sudo chown certbot-runner:certbot-runner /opt/certbot/aws.config;
  else
    echo "No access key given. Will use https validation." >&2;
    set -x;
  fi;
fi;

sudo cp "$BASEDIR/config/certbot-update.service" "$BASEDIR/config/certbot-update.timer" /lib/systemd/system/;
sudo chmod 0644 /lib/systemd/system/certbot-update.service /lib/systemd/system/certbot-update.timer;
sudo systemctl enable --now certbot-update.timer;

sudo cp "$BASEDIR/config/certbot.service" "$BASEDIR/config/certbot.timer" /lib/systemd/system/;
sudo chmod 0644 /lib/systemd/system/certbot.service /lib/systemd/system/certbot.timer;
sudo systemctl enable certbot.timer; # no --now (do not start updater while we are still installing)

# Prepare for certbot challenge

sudo mkdir -p /var/www/http/.well-known/acme-challenge;
sudo chown -R root:nginx /var/www/http;
sudo chown -R certbot-runner:nginx /var/www/http/.well-known/acme-challenge;

sed "s/((DOMAIN))/$DOMAIN/g" "$BASEDIR/config/http.conf" | \
  sudo tee /etc/nginx/sites-available/http > /dev/null;
sudo ln -s /etc/nginx/sites-available/http /etc/nginx/sites-ready/http || true;
sudo ln -s /etc/nginx/sites-available/http /etc/nginx/sites-enabled/http || true;

sed "s/((DOMAIN))/$DOMAIN/g" "$BASEDIR/config/nohost.conf" | \
  sudo tee /etc/nginx/sites-available/nohost > /dev/null;
sudo ln -s /etc/nginx/sites-available/nohost /etc/nginx/sites-ready/nohost || true;
sudo ln -s /etc/nginx/sites-available/nohost /etc/nginx/sites-enabled/nohost || true;

sudo mkdir -p /etc/letsencrypt/renewal-hooks/deploy;
install_config "$BASEDIR/config/certbot-deploy" /etc/letsencrypt/renewal-hooks/deploy 0755 || true;

# generate a "bomb" file to send to attackers

install_web_file() {
  local FILE="$1";
  sudo chown root:nginx "$FILE";
  sudo chmod 0644 "$FILE";
  sudo mv "$FILE" /var/www/http;
}

generate_bomb() {
  local BOMB_TEMP="$HOME";
  local EXTENSION="$1";

  if ! [ -f "/var/www/http/bomb.$EXTENSION" ] && ! [ -f "/var/www/http/bomb.$EXTENSION" ]; then
    "$BASEDIR/generate-bomb.mjs" "$EXTENSION" > "$BOMB_TEMP/bomb.$EXTENSION";
    install_web_file "$BOMB_TEMP/bomb.$EXTENSION";

    # (disabled for now because gzip loads full content in memory, and these instances are small)
    if false; then
      "$BASEDIR/generate-bomb.mjs" "$EXTENSION" --zipped | gzip -nc9 > "$BOMB_TEMP/bomb.$EXTENSION.gz";
    fi;
    # pick up gzipped file if it was added manually
    if [ -f "$BOMB_TEMP/bomb.$EXTENSION.gz" ]; then
      install_web_file "$BOMB_TEMP/bomb.$EXTENSION.gz";
    fi;
  fi;
}

generate_bomb html;
generate_bomb xml;
generate_bomb json;
generate_bomb yaml;

sudo nginx -t;

sudo systemctl enable --now nginx;
