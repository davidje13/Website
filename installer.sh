set -ex

BASEDIR="$(dirname "$0")";
DOMAIN="$1";

if [[ -z "$DOMAIN" ]]; then
	echo "Must specify domain! (e.g. 'davidje13.com')";
	exit 1;
fi;

echo 'iptables-persistent iptables-persistent/autosave_v4 boolean true' | sudo debconf-set-selections;
echo 'iptables-persistent iptables-persistent/autosave_v6 boolean true' | sudo debconf-set-selections;

sudo add-apt-repository ppa:certbot/certbot -y;
sudo apt-get update;
sudo apt-get dist-upgrade -y;

sudo apt-get install -y \
	unattended-upgrades \
	iptables-persistent \
	daemontools \
	certbot \
	nginx;
sudo systemctl stop nginx;

sudo cp "$BASEDIR/config/20auto-upgrades" /etc/apt/apt.conf.d/20auto-upgrades;
sudo cp "$BASEDIR/config/50unattended-upgrades" /etc/apt/apt.conf.d/50unattended-upgrades;

sudo mkdir -p /var/www/http/.well-known/acme-challenge;
sudo chown -R root:www-data /var/www/http;

if ! [[ -f /etc/nginx/dhparam.pem ]]; then
	openssl dhparam -out dhparam.pem 2048;
	sudo mv dhparam.pem /etc/nginx/dhparam.pem;
	sudo chmod 0600 /etc/nginx/dhparam.pem;
	sudo chown root:root /etc/nginx/dhparam.pem;
fi;

sudo rm /etc/nginx/modules-enabled/* || true;
sudo rm /etc/nginx/sites-enabled/* || true;
sudo ln -s /usr/share/nginx/modules-available/mod-stream.conf /etc/nginx/modules-enabled/50-mod-stream.conf;

sudo cp "$BASEDIR/config/nginx.conf" /etc/nginx/nginx.conf;
sudo cp "$BASEDIR/config/custom.conf" /etc/nginx/conf.d/custom.conf;
sudo cp "$BASEDIR/config/mime.conf" /etc/nginx/conf.d/mime.conf;

sudo cp "$BASEDIR/config/shared-ssl.inc" /etc/nginx/sites-available/shared-ssl.inc;

sudo cp "$BASEDIR/config/http" /etc/nginx/sites-available/http;
sudo ln -s /etc/nginx/sites-available/http /etc/nginx/sites-enabled/http;

sudo systemctl start nginx;

sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8000;
sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443;
sudo ip6tables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8000;
sudo ip6tables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443;
sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null;
sudo ip6tables-save | sudo tee /etc/iptables/rules.v6 > /dev/null;

sudo certbot certonly \
	--agree-tos \
	--register-unsafely-without-email \
	--cert-name all \
	--webroot \
	-w /var/www/http \
	-d "$DOMAIN" \
	-d "www.$DOMAIN" \
	-d "sequence.$DOMAIN";

sudo cp "$BASEDIR/config/certbot-deploy" /etc/letsencrypt/renewal-hooks/deploy/certbot-deploy;
sudo chmod 0755 /etc/letsencrypt/renewal-hooks/deploy/certbot-deploy;

export DOMAIN;
"$BASEDIR/www/installer.sh";
"$BASEDIR/sequence/installer.sh";

sudo nginx -s reload;

# thanks,
# https://gist.github.com/nrollr/9a39bb636a820fb97eec2ed85e473d38
# https://bjornjohansen.no/redirect-to-https-with-nginx
# http://tumblr.intranation.com/post/766288369/using-nginx-reverse-proxy
# https://certbot.eff.org/
# https://help.ubuntu.com/lts/serverguide/automatic-updates.html
# https://cloud-images.ubuntu.com/locator/ec2/
# https://gist.github.com/alonisser/a2c19f5362c2091ac1e7
# https://www.freedesktop.org/software/systemd/man/systemd.service.html
