set -ex

BASEDIR="$(dirname "$0")";

# Remove existing site if found
sudo rm -r /var/www/https || true;

# Install
sudo mkdir -p /var/www/https;
sudo cp "$BASEDIR/style.css" "$BASEDIR/favicon.png" "$BASEDIR/robots.txt" /var/www/https/;
sed "s/((DOMAIN))/$DOMAIN/g" "$BASEDIR/index.htm" | \
  sudo tee /var/www/https/index.htm > /dev/null;
sudo chown -R root:www-data /var/www/https;

# Add NGINX config

sed "s/((DOMAIN))/$DOMAIN/g" "$BASEDIR/site.conf" | \
  sudo tee /etc/nginx/sites-available/root > /dev/null;
