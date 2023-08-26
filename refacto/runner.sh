#!/bin/bash
BASEDIR="$(dirname "$0")";
export PORT="$1";
export TRUST_PROXY=true;

mkdir -p "$BASEDIR/logs/log$PORT";

"$BASEDIR/build/index.js" \
  > >(multilog t n50 s1048576 "$BASEDIR/logs/log$PORT") 2>&1 &

echo "$!" > "$BASEDIR/logs/pid$PORT";
