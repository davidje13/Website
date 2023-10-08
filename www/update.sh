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
sudo chown -R "$(whoami)" "$INSTALL_TEMP_DIR";

compress_gzip_static() {
  local TARGET_FILE="$1";
  gzip -nk9 "$TARGET_FILE";
  # if compression (plus overhead to account for headers / time
  # decompressing) did not reduce size, always serve uncompressed
  if (( "$(wc -c < "$TARGET_FILE.gz")" + 300 > "$(wc -c < "$TARGET_FILE")" )); then
    rm "$TARGET_FILE.gz";
  else
    chmod 0644 "$TARGET_FILE.gz";
  fi;
}

cd "$BASEDIR/static";
find . -type f | while IFS='' read -r SOURCE_FILE; do
  TARGET_FILE="$INSTALL_TEMP_DIR/$SOURCE_FILE";
  mkdir -p "${TARGET_FILE%/*}";
  chmod 0755 "${TARGET_FILE%/*}";
  if [[ "$SOURCE_FILE" =~ \.(txt|htm|xml)$ ]]; then
    sed -e "s/((DOMAIN))/$DOMAIN/g" "$SOURCE_FILE" > "$TARGET_FILE";
  else
    cp "$SOURCE_FILE" "$TARGET_FILE";
  fi;
  chmod 0644 "$TARGET_FILE";
  compress_gzip_static "$TARGET_FILE";
done;
cd - >/dev/null;

make_error_page() {
  local CODE="$1";
  local ERROR="$2";
  local TARGET_FILE="$INSTALL_TEMP_DIR/errors/$CODE.htm";
  sed \
    -e "s:./static/:/:g" \
    -e "s/((CODE))/$CODE/g" \
    -e "s/((DOMAIN))/$DOMAIN/g" \
    -e "s/((ERROR))/$ERROR/g" \
    "$BASEDIR/error.htm" > "$TARGET_FILE";
  chmod 0644 "$TARGET_FILE";
  compress_gzip_static "$TARGET_FILE";
}

set +x; # avoid super-verbose log output while copying error pages
while IFS='' read -r LINE; do
  if [[ -n "$LINE" ]]; then
    make_error_page "${LINE%%,*}" "${LINE#*,}";
  fi;
done < "$BASEDIR/http_statuses.csv";
set -x;

sudo chown -R root:nginx "$INSTALL_TEMP_DIR";

# Remove existing site if found and move new site in place
sudo rm -r "$INSTALL_DIR" || true;
sudo mv "$INSTALL_TEMP_DIR" "$INSTALL_DIR";
