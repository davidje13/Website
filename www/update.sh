#!/bin/bash
set -ex

if [[ -z "$DOMAIN" ]]; then
  set +x;
  echo "Must specify DOMAIN environment variable! (e.g. 'davidje13.com')" >&2;
  exit 1;
fi;

BASEDIR="$(dirname "$0")";

INSTALL_DIR="/var/www/https";
INSTALL_TEMP_DIR="/var/www/https2";

# Clear temp installation folder if found
sudo rm -r "$INSTALL_TEMP_DIR" || true;

# Install
sudo mkdir -p "$INSTALL_TEMP_DIR/errors";
sudo cp \
  "$BASEDIR/style.css" \
  "$BASEDIR/favicon.png" \
  "$BASEDIR/robots.txt" \
  "$BASEDIR/ads.txt" \
  "$INSTALL_TEMP_DIR/";

sed \
  "s/((DOMAIN))/$DOMAIN/g" \
  "$BASEDIR/index.htm" | \
  sudo tee "$INSTALL_TEMP_DIR/index.htm" > /dev/null;

make_error_page() {
  CODE="$1";
  ERROR="$2";
  sed \
    -e "s/((CODE))/$CODE/g" \
    -e "s/((DOMAIN))/$DOMAIN/g" \
    -e "s/((ERROR))/$ERROR/g" \
    "$BASEDIR/error.htm" | \
    sudo tee "$INSTALL_TEMP_DIR/errors/$CODE.htm" > /dev/null;
}

while IFS='' read -r LINE; do
  if [[ -n "$LINE" ]]; then
    make_error_page "${LINE%%,*}" "${LINE#*,}";
  fi;
done < "$BASEDIR/http_statuses";

sudo chown -R root:www-data "$INSTALL_TEMP_DIR";

# Remove existing site if found and move new site in place
sudo rm -r "$INSTALL_DIR" || true;
sudo mv "$INSTALL_TEMP_DIR" "$INSTALL_DIR";
