#!/bin/bash
set -e
BASEDIR="$(dirname "$0")";

cd "$BASEDIR/src";

sudo -u refacto-updater -H -s <<EOF || exit 0
git fetch || true;
sleep 1;
if (( "$(git rev-list HEAD..origin/master --count)" == 0 )); then
	exit 1;
fi;
EOF

sudo -u refacto-updater -H -s <<EOF
git pull;
npm run build;
cd build && DISABLE_OPENCOLLECTIVE=1 npm install --production; cd -;
EOF

chmod -R g-w /var/www/refacto/src/build;
chown -R root:refacto-runner /var/www/refacto/src/build;

rm -rf /var/www/refacto/build || true;
mv /var/www/refacto/src/build /var/www/refacto/build;

systemctl restart refacto4080.service;
systemctl restart refacto4081.service;
