#!/bin/bash
set -e
BASEDIR="$(dirname "$0")";

cd "$BASEDIR";

sudo -u sequence-updater -H -s <<EOF || [[ "$1" == "--force" ]] || exit 0
git fetch --prune || true;
sleep 1;
if (( "$(git rev-list HEAD..origin/master --count)" == 0 )); then
  exit 1;
fi;
EOF

sudo -u sequence-updater -H -s <<EOF
set -e;
git checkout .; # ensure clean git repo
git pull --ff-only;
EOF

chmod -R g-w .;

systemctl restart sequence8080.service;
systemctl restart sequence8081.service;
