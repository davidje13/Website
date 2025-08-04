#!/bin/sh
set -ex

BACKUP_FILE="backup-refacto-$(date "+%Y-%m-%dT%H-%M-%S").tar.gz";

rm -rf dump || true;
mongodump;
tar -czf "$BACKUP_FILE" dump;
rm -rf dump;

set +x;
echo "Created $BACKUP_FILE";
