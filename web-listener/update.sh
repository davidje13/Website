#!/bin/sh
set -e;

BASEDIR="$(dirname "$0")";
OLD_DIRS="$(ls /var/www/web-listener/sites)";
NEW_DIR="v$(date -u '+%Y%m%d%H%M%S')";
CONFIG_FILE="/var/www/web-listener/sites/config.json";

mkdir "/var/www/web-listener/sites/$NEW_DIR";
chown web-listener-updater:web-listener-runner "/var/www/web-listener/sites/$NEW_DIR";

for SITE in $(ls /var/www/web-listener/updaters); do
  if [ -d "/var/www/web-listener/updaters/$SITE" ]; then
    mkdir -p "/var/www/web-listener/sites/$NEW_DIR/$SITE";
    chmod 0750 "/var/www/web-listener/sites/$NEW_DIR/$SITE";
    chown web-listener-updater:web-listener-runner "/var/www/web-listener/sites/$NEW_DIR/$SITE";
    if ! sudo -u web-listener-updater -H "/var/www/web-listener/updaters/$SITE/update.sh" "/var/www/web-listener/sites/$NEW_DIR/$SITE"; then
      echo "Failed to update $SITE" >&2;
      rm -rf "/var/www/web-listener/sites/$NEW_DIR";
      exit 1;
    fi;
  fi;
done;

if [ -f "$CONFIG_FILE" ]; then
  mv "$CONFIG_FILE" "$CONFIG_FILE.backup";
fi;

{
  echo '{';
  echo '  "servers":[{"port":8080,"mount":[';
  for SITE in $(ls /var/www/web-listener/updaters); do
    if [ -d "/var/www/web-listener/updaters/$SITE" ]; then
      printf '    {"type":"delegate","path":"/%s","config":{"file":"/var/www/web-listener/sites/%s/%s/web-bundle.zip/config.json"}},\n' "$SITE" "$NEW_DIR" "$SITE";
    fi;
  done;
  echo '    {"type":"custom","method":"POST","path":"/","import":"/var/www/web-listener/deploy.mjs"}';
  echo '  ]}],';
  echo '  "logFormat": "json"';
  echo '}';
} > "$CONFIG_FILE";
chmod 0644 "$CONFIG_FILE";
chown web-listener-updater:web-listener-runner "$CONFIG_FILE";

chmod -R g-w "/var/www/web-listener/sites/$NEW_DIR";
chgrp -R web-listener-runner "/var/www/web-listener/sites/$NEW_DIR";

if ! sudo -u web-listener-runner /home/web-listener-runner/.local/bin/web-listener -c "$CONFIG_FILE" --no-serve; then
  echo "Config validation failed.";
  rm "$CONFIG_FILE";
  if [ -f "$CONFIG_FILE.backup" ]; then
    echo "Rolling back.";
    mv "$CONFIG_FILE.backup" "$CONFIG_FILE";
  fi;
  exit 1;
fi;

if ! echo " $* " | grep ' --nostart ' >/dev/null; then
  echo "restarting services";

  systemctl restart web-listener8080.service;
  systemctl restart web-listener8081.service;
fi;

for OLD_DIR in $OLD_DIRS; do
  if [ -d "/var/www/web-listener/sites/$OLD_DIR" ]; then
    # run as web-listener-updater rather than root to avoid risk of deleting
    # unexpected files if a sites/ folder has a space in the name (by accident or malice)
    echo "Removing old deployment: $OLD_DIR";
    sudo -u web-listener-updater -H rm -r "/var/www/web-listener/sites/$OLD_DIR";
  fi;
  rm "$CONFIG_FILE.backup" || true;
done;

echo "update complete";
