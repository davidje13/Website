set -ex

BASEDIR="$(dirname "$0")";

DOMAIN="$DOMAIN" "$BASEDIR/update.sh";

# Add NGINX config

sed "s/((DOMAIN))/$DOMAIN/g" "$BASEDIR/site.conf" | \
  sudo tee /etc/nginx/sites-available/root > /dev/null;
