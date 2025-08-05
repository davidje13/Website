#!/bin/sh
set -e

OLD_KEY="$1"
OLD_SERVER_USER="$2"
OLD_SERVER="$3"
NEW_KEY="$4"
NEW_SERVER_USER="$5"
NEW_SERVER="$6"
DOMAIN="$7"

if [ -z "$DOMAIN" ]; then
  echo "Must specify: $0 old_key old_server_user old_server_host new_key new_server_user new_server_host domain";
  exit 1;
fi;

echo "Preparing new server";
ssh -Ti "$NEW_KEY" "$NEW_SERVER_USER@$NEW_SERVER" \
  'sudo apt-get install -y git && git clone https://github.com/davidje13/Website.git ~/Website; Website/installer.sh || true; sudo shutdown -r now';

# Ensure old server scripts are up-to-date, make initial backup (later a second - offline - backup will be used to ensure no loss of data)
echo "Creating online backup";
ssh -Ti "$OLD_KEY" "$OLD_SERVER_USER@$OLD_SERVER" \
  'cd Website && git stash && git pull; cd ..; mkdir -p old-backups; mv backup-*.tar.gz old-backups || true; Website/refacto/backup.sh && mv backup-refacto-*.tar.gz backup-refacto-migrate-online.tar.gz';

# Wait for new server to be available again after reboot
echo "Waiting for new server to restart";
while ! ssh -qTi "$NEW_KEY" "$NEW_SERVER_USER@$NEW_SERVER"; do
  sleep 1
done;

# Copy backup files
echo "Transferring online backup";
scp -i "$OLD_KEY" "$OLD_SERVER_USER@$OLD_SERVER:/home/$OLD_SERVER_USER/backup-refacto-migrate-online.tar.gz" backup-refacto-migrate-online.tar.gz;
scp -i "$NEW_KEY" backup-refacto-migrate-online.tar.gz "$NEW_SERVER_USER@$NEW_SERVER:/home/$NEW_SERVER_USER/backup-refacto-migrate-online.tar.gz";

# Copy secrets
echo "Copying secrets";
ssh -qTi "$OLD_KEY" "$OLD_SERVER_USER@$OLD_SERVER" \
  'sudo cat /var/www/refacto/secrets.env' \
| ssh -qTi "$NEW_KEY" "$NEW_SERVER_USER@$NEW_SERVER" \
  'cat > Website/env/refacto.env && chmod 0400 Website/env/refacto.env';

# Install additional sites
echo;
echo "Action required: Install any additional sites and their data.";
echo "Also if DNS will be updated, set a low TTL now.";
echo;
echo "ssh -i '$NEW_KEY' '$NEW_SERVER_USER@$NEW_SERVER'";
echo;
echo "Press enter to continue";
read NEXT;

# Build new server
echo "Building new server";
ssh -Ti "$NEW_KEY" "$NEW_SERVER_USER@$NEW_SERVER" \
  "REFACTO_DATA_FILE=backup-refacto-migrate-online.tar.gz Website/installer.sh '$DOMAIN'";

echo "Fetching new server details for local testing";

# Get IP of new server
TEST_NEW_IP="$(ssh -qTi "$NEW_KEY" "$NEW_SERVER_USER@$NEW_SERVER" 'dig -4 +short myip.opendns.com A @resolver1.opendns.com')";

# Get domains of new server
TEST_NEW_DOMAINS="$(ssh -qTi "$NEW_KEY" "$NEW_SERVER_USER@$NEW_SERVER" 'cat /var/www/domains.txt')";

# Get certificate of new server
ssh -qTi "$NEW_KEY" "$NEW_SERVER_USER@$NEW_SERVER" 'sudo cat /var/www/selfsigned.crt' > selfsigned.crt;

# Update /etc/hosts on local machine for testing
echo "Updating /etc/hosts for testing";
sudo cp -p /etc/hosts /etc/hosts-original;
{
  printf '\n\n# TEMP TESTING:\n';
  for SUBDOMAIN in $TEST_NEW_DOMAINS; do
    printf "$SUBDOMAIN\t\t$TEST_NEW_IP\n";
  done;
} | tee -a /etc/hosts >/dev/null;

echo; # Manual check opportunity
echo "Action required: Add self-signed certificate (selfsigned.crt) to browser, then test site locally.";
echo "  for Firefox: Settings -> Privacy & Security -> View Certificates -> Authorities -> Import";
echo "Press enter to continue";
read NEXT;

echo "Restoring /etc/hosts";
sudo cp -fp /etc/hosts-original /etc/hosts;
sudo rm /etc/hosts-original;

# Shut down nginx on new server so that nobody accesses/modifies the current data
echo "Shutting down new server";
ssh -Ti "$NEW_KEY" "$NEW_SERVER_USER@$NEW_SERVER" \
  'sudo systemctl stop nginx && sudo systemctl disable nginx';

# Update DNS or elastic IP (partial outage begins)
echo;
echo "Action required: Update DNS records or elastic IP - this will begin the service outage window.";
echo "Press enter to continue.";
read NEXT;
echo;
echo "$(date) Partial outage begins";
echo;
printf "If elastic IP was reassigned, enter the new hostname for the old server (no longer using the elastic IP) here (else leave blank): ";
read UPDATED_OLD_SERVER;
if [ -n "$UPDATED_OLD_SERVER" ]; then
  NEW_SERVER="$OLD_SERVER";
  OLD_SERVER="$UPDATED_OLD_SERVER";
fi;

# Shut down services (guarantee no data changes) and create offline backup (full outage begins)
echo "Shutting down old server and creating offline backup";
echo "$(date) Full outage begins";
ssh -Ti "$OLD_KEY" "$OLD_SERVER_USER@$OLD_SERVER" \
  'mv backup-*.tar.gz old-backups || true; Website/refacto/backup.sh --offline && mv backup-refacto-*.tar.gz backup-refacto-migrate-offline.tar.gz';

# Copy offline backup to new server
echo "Transferring offline backup";
scp -i "$OLD_KEY" "$OLD_SERVER_USER@$OLD_SERVER:/home/$OLD_SERVER_USER/backup-refacto-migrate-offline.tar.gz" backup-refacto-migrate-offline.tar.gz;
scp -i "$NEW_KEY" backup-refacto-migrate-offline.tar.gz "$NEW_SERVER_USER@$NEW_SERVER:/home/$NEW_SERVER_USER/backup-refacto-migrate-offline.tar.gz";

# Restore from offline backup + start services, request certificates (outage ends once certificates are obtained)
echo "Restoring offline backup, starting new server, and requesting certificates";
ssh -Ti "$NEW_KEY" "$NEW_SERVER_USER@$NEW_SERVER" \
  'Website/refacto/restore.sh backup-refacto-migrate-offline.tar.gz && sudo systemctl enable nginx && sudo systemctl start nginx && sudo Website/proxy/get-certificate.sh';

echo "$(date) Outage ends";

echo;
echo "Deployment complete. The old server is still running. You may wish to download logs before terminating it.";
echo;
echo "ssh -i '$OLD_KEY' '$OLD_SERVER_USER@$OLD_SERVER'";
echo;
