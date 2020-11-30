#!/bin/bash
set -e
BASEDIR="$(dirname "$0")";

cd "$BASEDIR/src";

sudo -u refacto-updater -H -s <<EOF || [[ "$1" == "--force" ]] || exit 0
git fetch --prune || true;
sleep 1;
if (( "$(git rev-list HEAD..origin/master --count)" == 0 )); then
  exit 1;
fi;
EOF

sudo -u refacto-updater -H -s <<EOF
set -e;
git checkout .; # ensure clean git repo
git pull --ff-only;
npm run clean;
SKIP_E2E_DEPS=true npm install;
EOF

# refacto build uses ~0.7GB RAM, and instance has only 1GB total,
# so shut down current services to give it the most space
# (downtime begins!)
echo "$(date) - downtime begins (rebuilding Refacto)";
systemctl stop refacto4080.service;
systemctl stop refacto4081.service;
systemctl stop mongodb;

echo "$(date) - building";
sudo -u refacto-updater -H -s <<EOF || ( echo "rebuild failed; starting old services"; systemctl start mongodb; systemctl start refacto4080.service; systemctl start refacto4081.service; echo "downtime ends"; false; )
set -e;
PARALLEL_BUILD=false npm run build;
cd build && DISABLE_OPENCOLLECTIVE=1 npm install --production; cd -;
EOF

echo "$(date) - build complete";

chmod -R g-w /var/www/refacto/src/build;
chown -R root:refacto-runner /var/www/refacto/src/build;

rm -rf /var/www/refacto/build || true;
mv /var/www/refacto/src/build /var/www/refacto/build;

echo "$(date) - starting services";

systemctl start mongodb;
systemctl restart refacto4080.service;
systemctl restart refacto4081.service;

echo "$(date) - downtime ends";
