#!/bin/sh
BASEDIR="$(dirname "$0")";

set -e;

OLD_DIRS="$(ls /var/www/web-listener/sites)";
NEW_DIR="v$(date -u '+%Y%m%d%H%M%S')";

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
} > /var/www/web-listener/sites/config.json;
chmod 0644 /var/www/web-listener/sites/config.json;
chown web-listener-updater:web-listener-runner /var/www/web-listener/sites/config.json;

chmod -R g-w "/var/www/web-listener/sites/$NEW_DIR";
chgrp -R web-listener-runner "/var/www/web-listener/sites/$NEW_DIR";

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
done;

echo "update complete";
