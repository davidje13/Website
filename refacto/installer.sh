set -ex

BASEDIR="$(dirname "$0")";
SERVICE_PORTS="4080 4081";

if [[ ! -f "$BASEDIR/../env/refacto.env" ]]; then
	echo "Must populate env/refacto.env" >&2;
	exit 1;
fi;

# Make Users

sudo useradd --create-home --user-group --password '' refacto-updater || true;
sudo useradd --system --user-group --password '' refacto-runner || true;

# Load dependencies

sudo apt-get install -y nodejs mongodb;

# Load repository

mkdir -p ~/Refacto;
git clone https://github.com/davidje13/Refacto.git ~/Refacto;

# Shutdown existing services if found

for PORT in $SERVICE_PORTS; do
	sudo systemctl stop "refacto$PORT.service" || true;
done;
sudo rm -r /var/www/refacto || true;

# Build

sudo mkdir -p /var/www/refacto;
sudo mv ~/Refacto /var/www/refacto/src;
sudo chown -R refacto-updater:refacto-updater /var/www/refacto/src;
sudo -u refacto-updater -H -s <<EOF
cd /var/www/refacto/src && npm run build; cd - > /dev/null;
cd /var/www/refacto/src/build && DISABLE_OPENCOLLECTIVE=1 npm install --production; cd - > /dev/null;
EOF

# Install

sudo chmod -R g-w /var/www/refacto/src/build;
sudo chown -R root:refacto-runner /var/www/refacto/src/build;
sudo mv /var/www/refacto/src/build /var/www/refacto/build;
sudo mkdir -p /var/www/refacto/logs;

sudo mv "$BASEDIR/../env/refacto.env" /var/www/refacto/secrets.env;
sudo cp "$BASEDIR/runner.sh" /var/www/refacto/runner.sh;
sudo cp "$BASEDIR/update.sh" /var/www/refacto/update.sh;

sudo chown root:refacto-runner /var/www/refacto/secrets.env /var/www/refacto/update.sh;
sudo chown -R refacto-runner:refacto-runner /var/www/refacto/logs;
sudo chown refacto-runner:refacto-runner /var/www/refacto/runner.sh;
sudo chmod 0400 /var/www/refacto/secrets.env;
sudo chmod 0544 /var/www/refacto/runner.sh /var/www/refacto/update.sh;

# Start new services

for PORT in $SERVICE_PORTS; do
	NAME="refacto$PORT.service";
	sed "s/((PORT))/$PORT/g" "$BASEDIR/refacto.svc" | \
		sudo tee "/lib/systemd/system/$NAME" > /dev/null;
	sudo chmod 0644 "/lib/systemd/system/$NAME";
	sudo systemctl enable "$NAME";
	sudo systemctl start "$NAME";
done;

# Configure auto-update

sudo cp "$BASEDIR/refacto-pull" /etc/cron.daily/refacto-pull;
sudo chmod 0755 /etc/cron.daily/refacto-pull;

# Add NGINX config

sed "s/((DOMAIN))/$DOMAIN/g" "$BASEDIR/site.conf" | \
	sudo tee /etc/nginx/sites-available/refacto > /dev/null;
sudo ln -s /etc/nginx/sites-available/refacto /etc/nginx/sites-enabled/refacto;
