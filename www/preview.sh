#!/bin/sh
set -e;

BASEDIR="$(dirname "$0")";

PYTHON="python3";
if ! which "$PYTHON" >/dev/null; then
  PYTHON="python";
fi;
"$PYTHON" -m http.server -b 127.0.0.1 -d "$BASEDIR/static" 8080;
