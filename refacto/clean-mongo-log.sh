#!/bin/sh
set -e

echo "$(date) - cleaning Mongo logs ($0)";

# rotate /var/log/mongodb/mongod.log
sudo pkill -SIGUSR1 -u mongodb mongod;

# wait for log files to update
sleep 1;

# filter out useless WiredTiger checkpoint logs (VERY verbose, but no config options allow disabling these, so we have to filter them after-the-fact) and compress
cd /var/log/mongodb/;
for LOGFILE in mongod.log.*; do
  if [ -f "$LOGFILE" ]; then
    OUTFILE="reduced-$LOGFILE";
    sudo cat "$LOGFILE" | grep -v '"s":"I",  "c":"WTCHKPT"' > "$OUTFILE";
    gzip "$OUTFILE";
    chmod 0640 "$OUTFILE.gz";
    sudo chown root:mongodb "$OUTFILE.gz";
    sudo rm "$LOGFILE";
  fi;
done;
cd - >/dev/null;
