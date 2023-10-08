set -ex

BASEDIR="$(dirname "$0")";
. "$BASEDIR/../common/utils.sh";
SERVICE_PORTS="8080 8081";

if [[ -f /etc/nginx/sites-available/sequence ]]; then
  # already installed
  exit 0;
fi;

# Make Users

sudo useradd --create-home --user-group --password '' sequence-updater || true;
sudo useradd --system --user-group --password '' sequence-runner || true;

# Load dependencies

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs;

# Load repository

mkdir -p ~/SequenceDiagram;
git clone https://github.com/davidje13/SequenceDiagram.git ~/SequenceDiagram;
cd ~/SequenceDiagram && DISABLE_OPENCOLLECTIVE=1 npm install --omit=dev; cd - > /dev/null;

# Shutdown existing services if found

for PORT in $SERVICE_PORTS; do
  sudo systemctl stop "sequence$PORT.service" || true;
done;
sudo rm -r /var/www/sequence || true;

# Install

sudo mv ~/SequenceDiagram /var/www/sequence;
sudo mkdir -p /var/www/sequence/logs;

sudo cp "$BASEDIR/runner.sh" /var/www/sequence/runner.sh;
sudo cp "$BASEDIR/update.sh" /var/www/sequence/update.sh;

sudo chmod -R g-w /var/www/sequence;
sudo chown -R sequence-updater:sequence-runner /var/www/sequence;
sudo chown -R sequence-runner:sequence-runner /var/www/sequence/logs;
sudo chown sequence-runner:sequence-runner /var/www/sequence/runner.sh;
sudo chown root:sequence-runner /var/www/sequence/update.sh;
sudo chmod 0544 /var/www/sequence/runner.sh /var/www/sequence/update.sh;

# Start new services

for PORT in $SERVICE_PORTS; do
  NAME="sequence$PORT.service";
  sed "s/((PORT))/$PORT/g" "$BASEDIR/sequence.svc" | \
    sudo tee "/lib/systemd/system/$NAME" > /dev/null;
  sudo chmod 0644 "/lib/systemd/system/$NAME";
  sudo systemctl enable "$NAME";
  sudo systemctl start "$NAME";
done;

# Configure auto-update

sudo cp "$BASEDIR/sequence-pull" /etc/cron.daily/sequence-pull;
sudo chmod 0755 /etc/cron.daily/sequence-pull;

# Add NGINX config

sed "s/((DOMAIN))/$DOMAIN/g" "$BASEDIR/site.conf" | \
  sudo tee /etc/nginx/sites-available/sequence > /dev/null;
