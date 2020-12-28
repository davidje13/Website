#!/bin/bash
BASEDIR="$(dirname "$0")";
export PORT="$1";
export TRUST_PROXY=true;

mkdir -p "$BASEDIR/logs/log$PORT";

"$BASEDIR/build/index.js" 2>&1 > >(multilog n50 s1048576 "$BASEDIR/logs/log$PORT") &

echo "$!" > "$BASEDIR/logs/pid$PORT";
