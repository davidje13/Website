#!/bin/sh
set -ex

SERVICE_PORTS="4080 4081";
if echo " $* " | grep ' --offline ' >/dev/null; then
  for PORT in $SERVICE_PORTS; do
    sudo systemctl disable --now "refacto$PORT.service";
  done;
fi;

BACKUP_FILE="backup-refacto-$(date "+%Y-%m-%dT%H-%M-%S").tar.gz";

rm -rf dump || true;
mongodump;
tar -czf "$BACKUP_FILE" dump;
rm -rf dump;

set +x;
echo "Created $BACKUP_FILE";
