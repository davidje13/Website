#!/bin/sh
BASEDIR="$(dirname "$0")";

FORCE_UPDATE=false;
if echo " $* " | grep ' --force ' >/dev/null; then
  FORCE_UPDATE=true;
fi;

cd "$BASEDIR";

FORCE_UPDATE="$FORCE_UPDATE" \
sudo --preserve-env="FORCE_UPDATE" -u sequence-updater -H -s <<"EOF"
git fetch --prune;
sleep 1;
CHANGES="$(git rev-list HEAD..origin/master --count)";
if [ "$FORCE_UPDATE" != "true" ] && [ "$CHANGES" -eq 0 ]; then
  echo "nothing to update (no changes)";
  exit 99;
fi;

echo "updating";

git checkout .; # ensure clean git repo
git pull --ff-only;
chmod -R g-w .;
EOF

STATUS="$?";
if [ "$STATUS" = 99 ]; then
  exit 0; # nothing to update
elif [ "$STATUS" != 0 ]; then
  exit "$STATUS"; # error
fi;

set -e;

chgrp -R sequence-runner .;

systemctl restart sequence8080.service;
systemctl restart sequence8081.service;
