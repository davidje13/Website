#!/bin/bash
set -ex

BACKUP_FILE="$1";

if [[ -z "$BACKUP_FILE" ]]; then
  set +x;
  echo "Must specify backup file (.tar.gz)" >&2;
  exit 1;
fi;

rm -rf temp-backup || true;
mkdir -p temp-backup;
tar -xzf "$1" -C temp-backup;
mongorestore temp-backup/dump;
rm -rf temp-backup;
