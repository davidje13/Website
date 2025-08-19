#!/bin/sh
set -e;

BASEDIR="$(dirname "$0")";

FOLDER="backup-$(date "+%Y-%m-%dT%H-%M-%S")";

mkdir "$FOLDER";
cd "$FOLDER";

for BACKUP_SCRIPT in "../$BASEDIR/"*/backup.sh; do
  "$BACKUP_SCRIPT";
done;

for BACKUP_SCRIPT in "$HOME/additional-sites/"*/backup.sh; do
  "$BACKUP_SCRIPT";
done;

mkdir logs;
cp /var/log/nginx/* logs;
cp -R /var/www/refacto/logs/log* logs;
cp -R /var/www/sequence/logs/log* logs;

cd ..;
tar -czf "$FOLDER.tar.gz" "$FOLDER";
rm -rf "$FOLDER";
