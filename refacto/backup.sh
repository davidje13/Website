#!/bin/sh
set -ex

BASEDIR="$(dirname "$0")";
SERVICE_PORTS="4080 4081";
if echo " $* " | grep ' --offline ' >/dev/null; then
  for PORT in $SERVICE_PORTS; do
    sudo systemctl disable --now "refacto$PORT.service";
  done;
fi;

BACKUP_FILE="backup-refacto-$(date "+%Y-%m-%dT%H-%M-%S").tar.gz";

rm -rf dump || true;
sudo cat "$BASEDIR/../env/mongo-backup-password" | mongodump --db=refacto --authenticationDatabase=admin -u backup;
tar -czf "$BACKUP_FILE" dump;
rm -rf dump;

set +x;
echo "Created $BACKUP_FILE";
