#!/bin/sh
set -e

ASSETS_DIR="/var/www/assets";

compress_gzip_static() {
  local TARGET_FILE="$1";
  gzip -nk9 "$TARGET_FILE";
  # if compression (plus overhead to account for headers / time
  # decompressing) did not reduce size, always serve uncompressed
  RAW_SIZE="$(wc -c < "$TARGET_FILE")";
  GZ_SIZE="$(wc -c < "$TARGET_FILE.gz")";
  if [ "$((GZ_SIZE + 300))" -gt "$RAW_SIZE" ]; then
    rm "$TARGET_FILE.gz";
  else
    chmod 0644 "$TARGET_FILE.gz";
  fi;
}

# Maybe include this too, but this particular build does not work on mac
# https://raw.githubusercontent.com/googlefonts/noto-emoji/raw/refs/heads/main/fonts/NotoColorEmoji-flagsonly.ttf

ASSET_SOURCES="$(cat <<EOF
https://raw.githubusercontent.com/adobe-fonts/adobe-notdef/refs/heads/master/AND-Regular.otf
https://raw.githubusercontent.com/google/fonts/refs/heads/main/ofl/notocoloremoji/NotoColorEmoji-Regular.ttf
https://raw.githubusercontent.com/google/fonts/refs/heads/main/ofl/notoemoji/NotoEmoji[wght].ttf
https://raw.githubusercontent.com/notofonts/noto-cjk/refs/heads/main/Sans/SubsetOTF/HK/NotoSansHK-Regular.otf
https://raw.githubusercontent.com/notofonts/noto-cjk/refs/heads/main/Sans/SubsetOTF/JP/NotoSansJP-Regular.otf
https://raw.githubusercontent.com/notofonts/noto-cjk/refs/heads/main/Sans/SubsetOTF/KR/NotoSansKR-Regular.otf
https://raw.githubusercontent.com/notofonts/noto-cjk/refs/heads/main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf
https://raw.githubusercontent.com/notofonts/noto-cjk/refs/heads/main/Sans/SubsetOTF/TC/NotoSansTC-Regular.otf
https://raw.githubusercontent.com/notofonts/notofonts.github.io/refs/heads/main/megamerge/NotoSansHistorical-Regular.ttf
https://raw.githubusercontent.com/notofonts/notofonts.github.io/refs/heads/main/megamerge/NotoSansLiving-Regular.ttf
https://raw.githubusercontent.com/notofonts/notofonts.github.io/refs/heads/main/fonts/NotoMusic/unhinted/otf/NotoMusic-Regular.otf
https://raw.githubusercontent.com/notofonts/notofonts.github.io/refs/heads/main/fonts/NotoSansDuployan/unhinted/otf/NotoSansDuployan-Regular.otf
https://raw.githubusercontent.com/notofonts/notofonts.github.io/refs/heads/main/fonts/NotoSansSignWriting/unhinted/otf/NotoSansSignWriting-Regular.otf
https://raw.githubusercontent.com/notofonts/notofonts.github.io/refs/heads/main/fonts/NotoSansSymbols2/unhinted/otf/NotoSansSymbols2-Regular.otf
https://raw.githubusercontent.com/notofonts/notofonts.github.io/refs/heads/main/fonts/NotoSerifDivesAkuru/unhinted/otf/NotoSerifDivesAkuru-Regular.otf
https://raw.githubusercontent.com/notofonts/notofonts.github.io/refs/heads/main/fonts/NotoSerifDogra/unhinted/otf/NotoSerifDogra-Regular.otf
https://raw.githubusercontent.com/notofonts/notofonts.github.io/refs/heads/main/fonts/NotoSerifHentaigana/unhinted/otf/NotoSerifHentaigana-Regular.otf
https://raw.githubusercontent.com/notofonts/notofonts.github.io/refs/heads/main/fonts/NotoSerifKhitanSmallScript/unhinted/otf/NotoSerifKhitanSmallScript-Regular.otf
https://raw.githubusercontent.com/notofonts/notofonts.github.io/refs/heads/main/fonts/NotoSerifMakasar/unhinted/otf/NotoSerifMakasar-Regular.otf
https://raw.githubusercontent.com/notofonts/notofonts.github.io/refs/heads/main/fonts/NotoSerifNPHmong/unhinted/otf/NotoSerifNPHmong-Regular.otf
https://raw.githubusercontent.com/notofonts/notofonts.github.io/refs/heads/main/fonts/NotoSerifOldUyghur/unhinted/otf/NotoSerifOldUyghur-Regular.otf
https://raw.githubusercontent.com/notofonts/notofonts.github.io/refs/heads/main/fonts/NotoSerifOttomanSiyaq/unhinted/otf/NotoSerifOttomanSiyaq-Regular.otf
https://raw.githubusercontent.com/notofonts/notofonts.github.io/refs/heads/main/fonts/NotoSerifTangut/unhinted/otf/NotoSerifTangut-Regular.otf
https://raw.githubusercontent.com/notofonts/notofonts.github.io/refs/heads/main/fonts/NotoSerifTodhri/unhinted/otf/NotoSerifTodhri-Regular.otf
https://raw.githubusercontent.com/notofonts/notofonts.github.io/refs/heads/main/fonts/NotoSerifToto/unhinted/otf/NotoSerifToto-Regular.otf
https://raw.githubusercontent.com/notofonts/notofonts.github.io/refs/heads/main/fonts/NotoZnamennyMusicalNotation/unhinted/otf/NotoZnamennyMusicalNotation-Regular.otf
EOF
)";

if ! [ -f "$ASSETS_DIR/content/AND.license" ]; then
  curl -fsSL "https://raw.githubusercontent.com/adobe-fonts/adobe-notdef/refs/heads/master/LICENSE.md" > "$ASSETS_DIR/content/AND.license";
  curl -fsSL "https://raw.githubusercontent.com/googlefonts/noto-emoji/refs/heads/main/fonts/LICENSE" > "$ASSETS_DIR/content/NotoColorEmoji.license";
  curl -fsSL "https://raw.githubusercontent.com/google/fonts/refs/heads/main/ofl/notoemoji/OFL.txt" > "$ASSETS_DIR/content/NotoEmoji.license";
  curl -fsSL "https://raw.githubusercontent.com/notofonts/noto-cjk/refs/heads/main/Sans/LICENSE" > "$ASSETS_DIR/content/NotoCJK.license";
  curl -fsSL "https://raw.githubusercontent.com/notofonts/notofonts.github.io/refs/heads/main/fonts/LICENSE" > "$ASSETS_DIR/content/Noto.license";
fi;
for ASSET in $ASSET_SOURCES; do
  FILE="$ASSETS_DIR/content/$(basename "$ASSET")";
  if ! [ -f "$FILE" ]; then
    # ideally we would rely on --timestamping to fetch files if they have changed, but githubusercontent does not check if-modified-since
    wget --no-directories --timestamping --max-redirect=0 -P "$ASSETS_DIR/content" "$ASSET";
    chmod 0644 "$ASSET";
  fi;
  if ! [ -f "$FILE.gz" ] || [ "$FILE" -nt "$FILE.gz" ]; then
    rm "$FILE.gz" || true;
    compress_gzip_static "$FILE";
  fi;
done;

mkdir -p "$ASSETS_DIR/schema";

curl 'https://registry.npmjs.org/web-listener' | \
  jq -r '.versions | to_entries[] | (.key + "@" + .value.dist.tarball)' | \
  while IFS='' read -r LINE; do
    if [ -n "$LINE" ]; then
      VERSION="$(echo "$LINE" | cut -d'@' -f1 | sed 's/[^A-Za-z0-9.]//g')";
      URL="$(echo "$LINE" | cut -d'@' -f2-)";
      FILE="$ASSETS_DIR/schema/web-listener.$VERSION.json";
      if ! [ -f "$FILE" ]; then
        curl "$URL" | tar -xzO --include package/schema.json > "$FILE";
        chmod 0644 "$ASSET";
        compress_gzip_static "$FILE";
      fi;
    fi;
  done;
