set -ex

BASEDIR="$(dirname "$0")";

# Remove existing site if found
sudo rm -r /var/www/https || true;

# Install
sudo mkdir -p /var/www/https/errors;
sudo cp \
  "$BASEDIR/style.css" \
  "$BASEDIR/favicon.png" \
  "$BASEDIR/robots.txt" \
  "$BASEDIR/ads.txt" \
  /var/www/https/;

sed \
  "s/((DOMAIN))/$DOMAIN/g" \
  "$BASEDIR/index.htm" | \
  sudo tee /var/www/https/index.htm > /dev/null;

make_error_page() {
  CODE="$1";
  ERROR="$2";
  sed \
    -e "s/((CODE))/$CODE/g" \
    -e "s/((DOMAIN))/$DOMAIN/g" \
    -e "s/((ERROR))/$ERROR/g" \
    "$BASEDIR/error.htm" | \
    sudo tee "/var/www/https/errors/$CODE.htm" > /dev/null;
}

while IFS='' read -r LINE; do
  if [[ -n "$LINE" ]]; then
    make_error_page "${LINE%%,*}" "${LINE#*,}";
  fi;
done < "$BASEDIR/http_statuses";

sudo chown -R root:www-data /var/www/https;

# Add NGINX config

sed "s/((DOMAIN))/$DOMAIN/g" "$BASEDIR/site.conf" | \
  sudo tee /etc/nginx/sites-available/root > /dev/null;
