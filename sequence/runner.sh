#!/bin/sh
set -e

BASEDIR="$(dirname "$0")";
PORT="$1";
export FONTDIR="$BASEDIR/fonts";

LOG_DIR="$BASEDIR/logs/log$PORT";
LOG_PIPE="$BASEDIR/logs/pipe$PORT";
PID_FILE="$BASEDIR/logs/pid$PORT";

mkdir -p "$LOG_DIR";
if ! [ -p "$LOG_PIPE" ]; then
  if [ -e "$LOG_PIPE" ]; then
    rm "$LOG_PIPE";
  fi;
  mkfifo -m 0600 "$LOG_PIPE";
fi;

"$BASEDIR/dev-bin/server.mjs" "$PORT" > "$LOG_PIPE" 2>&1 &
echo "$!" > "$PID_FILE";

multilog t n50 s1048576 "$LOG_DIR" < "$LOG_PIPE" &
