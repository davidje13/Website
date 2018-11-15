#!/bin/bash
BASEDIR="$(dirname "$0")";

cd "$BASEDIR";
git fetch;
if (( "$(git rev-list HEAD..origin/master --count)" > 0 )); then
	git pull;
	chmod -R g-w .;
	systemctl restart sequence8080.service;
	systemctl restart sequence8081.service;
fi;
cd - > /dev/null;
