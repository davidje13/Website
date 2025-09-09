#!/bin/sh
BASEDIR="$(dirname "$0")";

FORCE_UPDATE=false;
if echo " $* " | grep ' --force ' >/dev/null; then
  FORCE_UPDATE=true;
fi;

UPDATE_DIR="$BASEDIR/update";

# GitHub rate limit for fetching public release info is 60/hour - we configure our rate in refacto-update.timer
# https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api?apiVersion=2022-11-28#primary-rate-limit-for-unauthenticated-users

FORCE_UPDATE="$FORCE_UPDATE" \
UPDATE_DIR="$UPDATE_DIR" \
sudo --preserve-env="FORCE_UPDATE,UPDATE_DIR" -u refacto-updater -H -s <<"EOF"
set -e;

CURRENT_RELEASE_ID="$(cat "$UPDATE_DIR/current" 2>/dev/null || echo 'none')";
RELEASE_INFO="$(curl -fsSL 'https://api.github.com/repos/davidje13/Refacto/releases/latest')";
RELEASE_ID="$(echo "$RELEASE_INFO" | jq -r '.id')";
if [ "$FORCE_UPDATE" != "true" ] && [ "$CURRENT_RELEASE_ID" = "$RELEASE_ID" ]; then
  echo "nothing to update ($CURRENT_RELEASE_ID is still latest version)";
  exit 99;
fi;

echo "updating from $CURRENT_RELEASE_ID to $RELEASE_ID";

rm -rf "$UPDATE_DIR/build" || true;
mkdir "$UPDATE_DIR/build";
cd "$UPDATE_DIR/build";

DOWNLOAD_URL="$(echo "$RELEASE_INFO" | jq -r '.assets[] | select(.name == "build.tar.gz") | .browser_download_url')";
echo "download from $DOWNLOAD_URL";
curl -fsSL "$DOWNLOAD_URL" >build.tar.gz;
tar -xf build.tar.gz;
rm build.tar.gz;

echo "install dependencies";
npm install --omit=dev;
chmod -R g-w .;
echo "$RELEASE_ID" > "../current";
EOF
STATUS="$?";
if [ "$STATUS" = 99 ]; then
  exit 0; # nothing to update
elif [ "$STATUS" != 0 ]; then
  exit "$STATUS"; # error
fi;

set -e;

chown -R root:refacto-runner "$UPDATE_DIR/build";
rm -rf /var/www/refacto/build || true;
mv "$UPDATE_DIR/build" /var/www/refacto/build;

if ! echo " $* " | grep ' --nostart ' >/dev/null; then
  echo "restarting services";

  systemctl restart refacto4080.service;
  systemctl restart refacto4081.service;
fi;

echo "update complete";
