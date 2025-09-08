#!/bin/sh
set -e
BASEDIR="$(dirname "$0")";

TEMP_INSTALL_DIR="$BASEDIR/update";
rm -rf "$TEMP_INSTALL_DIR" || true;
mkdir -p "$TEMP_INSTALL_DIR";
sudo chown -R refacto-updater:refacto-updater "$TEMP_INSTALL_DIR";

# GitHub rate limit for fetching public release info is 60/hour - we configure our rate in refacto-update.timer
# https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api?apiVersion=2022-11-28#primary-rate-limit-for-unauthenticated-users

echo "curl -fsSL 'https://api.github.com/repos/davidje13/Refacto/releases/latest'" | sudo -u refacto-updater -H -s >"$TEMP_INSTALL_DIR/release_info.json";
RELEASE_ID="$(jq -r '.id' <"$TEMP_INSTALL_DIR/release_info.json")";
if ! echo " $* " | grep ' --force ' >/dev/null && [ -f "$BASEDIR/current" ] && [ "$(cat "$BASEDIR/current")" = "$RELEASE_ID" ]; then
  echo "nothing to update (latest release is still $RELEASE_ID)";
  exit 0;
fi;

echo "installing release $RELEASE_ID";

cd "$TEMP_INSTALL_DIR";
sudo -u refacto-updater -H -s <<"EOF"
set -e;
DOWNLOAD_URL="$(jq -r '.assets[] | select(.name == "build.tar.gz") | .browser_download_url' <release_info.json)";
echo "download from $DOWNLOAD_URL";
curl -fL "$DOWNLOAD_URL" >build.tar.gz;
tar -xf build.tar.gz;
rm build.tar.gz release_info.json;
echo "install dependencies";
npm install --omit=dev;
EOF
cd - > /dev/null;
sudo chmod -R g-w "$TEMP_INSTALL_DIR";
sudo chown -R root:refacto-runner "$TEMP_INSTALL_DIR";

sudo rm -rf /var/www/refacto/build || true;
sudo mv "$TEMP_INSTALL_DIR" /var/www/refacto/build;
echo "$RELEASE_ID" | sudo tee /var/www/refacto/current >/dev/null;
sudo chown refacto-updater:refacto-updater /var/www/refacto/current;

if ! echo " $* " | grep ' --nostart ' >/dev/null; then
  echo "restarting services";

  sudo systemctl restart refacto4080.service;
  sudo systemctl restart refacto4081.service;
fi;

echo "update complete";
