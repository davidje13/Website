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
sudo cp /var/log/nginx/* logs;
sudo cp -R /var/www/refacto/logs/log* logs;
sudo cp -R /var/www/sequence/logs/log* logs;
sudo cp -R /var/www/monitor/logs/stats* logs;
sudo chmod -R 0700 logs;
sudo chown -R "$(whoami)" logs;
find logs -type f -exec chmod 600 {} \;;

cd ..;
tar -czf "$FOLDER.tar.gz" "$FOLDER";
rm -rf "$FOLDER";
