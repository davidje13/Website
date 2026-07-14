#!/bin/sh
set -e

UPDATERDIR="$(dirname "$0")";
OUT_DIR="$1";

ZIP_FILE="$OUT_DIR/raw.zip";
curl -L 'https://gitlab.com/api/v4/projects/davidje13%2Flean-qr/jobs/artifacts/main/download?job=sign' > "$ZIP_FILE";
unzip "$ZIP_FILE" -d "$OUT_DIR";
rm "$ZIP_FILE";

if ! openssl dgst -sha256 -verify "$UPDATERDIR/public.pem" -signature "$OUT_DIR/web-bundle.zip.sign" "$OUT_DIR/web-bundle.zip"; then
  echo "Signature mismatch!" >&2;
  rm -r "$OUT_DIR";
  exit 1;
fi
