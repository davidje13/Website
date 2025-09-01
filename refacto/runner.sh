#!/bin/sh
set -e

BASEDIR="$(dirname "$0")";
export PORT="$1";
export TRUST_PROXY="true";
export ANALYTICS_EVENT_DETAIL="message";
export ANALYTICS_CLIENT_ERROR_DETAIL="version";

# configure ws optional dependencies
export WS_NO_BUFFER_UTIL=true; # do not look for bufferutil dependency which is not installed
export WS_NO_UTF_8_VALIDATE=true; # not required in Node >= 18.14.0

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

"$BASEDIR/build/index.js" > "$LOG_PIPE" 2>&1 &
echo "$!" > "$PID_FILE";

multilog t n50 s1048576 "$LOG_DIR" < "$LOG_PIPE" &
