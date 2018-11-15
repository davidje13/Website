#!/bin/bash
BASEDIR="$(dirname "$0")";
PORT="$1";

mkdir -p "$BASEDIR/logs/log$PORT";

FONTDIR="$BASEDIR/fonts" \
"$BASEDIR/bin/server.js" "$PORT" 2>&1 \
	> >(multilog n50 s1048576 "$BASEDIR/logs/log$PORT") &

echo "$!" > "$BASEDIR/logs/pid$PORT";
