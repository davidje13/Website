#!/bin/sh
set -e

TARGET_DIR="$1";
if [ -z "$TARGET_DIR" ]; then
	echo "Must provide output directory for keys" >&2;
	exit 1;
fi;

if [ -f "$TARGET_DIR/private.pem" ]; then
  printf "Keys already exist in $TARGET_DIR - overwrite? [y/N]: ";
  read OVERWRITE;
  echo;
  if ! [ "$OVERWRITE" = "y" ]; then
		echo "Not overwriting" >&2;
		exit 1;
  fi;
fi;

mkdir -p "$TARGET_DIR";
OLD_UMASK="$(umask)";
umask 077;
openssl rand -base64 30 > "$TARGET_DIR/private.pass";
openssl genrsa -aes256 -passout "file:$TARGET_DIR/private.pass" -out "$TARGET_DIR/private.pem" 4096;
umask "$OLD_UMASK";
openssl rsa -in "$TARGET_DIR/private.pem" -passin "file:$TARGET_DIR/private.pass" -pubout -out "$TARGET_DIR/public.pem";
echo "Keys generated in $TARGET_DIR" >&2;
