#!/bin/bash
BASEDIR="$(dirname "$0")";
export PORT="$1";
export TRUST_PROXY=true;

# configure ws optional dependencies
export WS_NO_BUFFER_UTIL=true; # do not look for bufferutil dependency which is not installed
export WS_NO_UTF_8_VALIDATE=true; # not required in Node >= 18.14.0

mkdir -p "$BASEDIR/logs/log$PORT";

"$BASEDIR/build/index.js" \
  > >(multilog t n50 s1048576 "$BASEDIR/logs/log$PORT") 2>&1 &

echo "$!" > "$BASEDIR/logs/pid$PORT";
