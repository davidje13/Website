#!/bin/sh
set -e
BASEDIR="$(dirname "$0")";

cd "$BASEDIR";

echo 'git fetch --prune' | sudo -u sequence-updater -H -s;
sleep 1;
CHANGES="$(echo 'git rev-list HEAD..origin/master --count' | sudo -u sequence-updater -H -s)";
if [ "$CHANGES" -eq 0 ] && ! echo " $* " | grep ' --force ' >/dev/null; then
  exit 0; # nothing to update
fi;

echo 'git checkout .' | sudo -u sequence-updater -H -s; # ensure clean git repo
echo 'git pull --ff-only' | sudo -u sequence-updater -H -s;

chmod -R g-w .;
chgrp -R sequence-runner .;

systemctl restart sequence8080.service;
systemctl restart sequence8081.service;
