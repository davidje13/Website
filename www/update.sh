#!/bin/sh
set -ex

if [ -z "$DOMAIN" ]; then
  set +x;
  echo "Must specify DOMAIN environment variable! (e.g. 'davidje13.com')" >&2;
  exit 1;
fi;

BASEDIR="$(dirname "$0")";

INSTALL_DIR="/var/www/https";
INSTALL_TEMP_DIR="/var/www/https2";
ASSETS_DIR="/var/www/assets";

# Clear temp installation folder if found
sudo rm -r "$INSTALL_TEMP_DIR" || true;

# Install
sudo mkdir -p "$INSTALL_TEMP_DIR/errors";
sudo chown -R "$(whoami)" "$INSTALL_TEMP_DIR";

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

cd "$BASEDIR/static";
find . -type f | while IFS='' read -r SOURCE_FILE; do
  TARGET_FILE="$INSTALL_TEMP_DIR/$SOURCE_FILE";
  TARGET_DIR="$(dirname "$TARGET_FILE")";
  mkdir -p "$TARGET_DIR";
  chmod 0755 "$TARGET_DIR";
  case "$SOURCE_FILE" in
  *.txt|*.htm|*.xml)
    sed -e "s/((DOMAIN))/$DOMAIN/g" "$SOURCE_FILE" > "$TARGET_FILE";
    ;;
  *)
    cp "$SOURCE_FILE" "$TARGET_FILE";
    ;;
  esac;
  chmod 0644 "$TARGET_FILE";
  compress_gzip_static "$TARGET_FILE";
done;
cd - >/dev/null;

make_error_page() {
  local CODE="$1";
  local ERROR="$2";
  local TARGET_FILE="$INSTALL_TEMP_DIR/errors/$CODE.htm";
  sed \
    -e "s:./static/:/:g" \
    -e "s/((CODE))/$CODE/g" \
    -e "s/((DOMAIN))/$DOMAIN/g" \
    -e "s/((ERROR))/$ERROR/g" \
    "$BASEDIR/error.htm" > "$TARGET_FILE";
  chmod 0644 "$TARGET_FILE";
  compress_gzip_static "$TARGET_FILE";
}

set +x; # avoid super-verbose log output while copying error pages
while IFS='' read -r LINE; do
  if [ -n "$LINE" ]; then
    CODE="$(echo "$LINE" | cut -d',' -f1)";
    ERROR="$(echo "$LINE" | cut -d',' -f2)";
    make_error_page "$CODE" "$ERROR";
  fi;
done < "$BASEDIR/http_statuses.csv";
set -x;

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

sudo mkdir -p "$ASSETS_DIR";
sudo chown -R "$(whoami):nginx" "$ASSETS_DIR";
if [ ! -f "$ASSETS_DIR/AND.license" ]; then
  curl -fsSL "https://raw.githubusercontent.com/adobe-fonts/adobe-notdef/refs/heads/master/LICENSE.md" > "$ASSETS_DIR/AND.license";
  curl -fsSL "https://raw.githubusercontent.com/googlefonts/noto-emoji/refs/heads/main/fonts/LICENSE" > "$ASSETS_DIR/NotoColorEmoji.license";
  curl -fsSL "https://raw.githubusercontent.com/google/fonts/refs/heads/main/ofl/notoemoji/OFL.txt" > "$ASSETS_DIR/NotoEmoji.license";
  curl -fsSL "https://raw.githubusercontent.com/notofonts/noto-cjk/refs/heads/main/Sans/LICENSE" > "$ASSETS_DIR/NotoCJK.license";
  curl -fsSL "https://raw.githubusercontent.com/notofonts/notofonts.github.io/refs/heads/main/fonts/LICENSE" > "$ASSETS_DIR/Noto.license";
fi;
for ASSET in $ASSET_SOURCES; do
  FILE="$ASSETS_DIR/$(basename "$ASSET")";
  if [ ! -f "$FILE" ]; then
    # ideally we would rely on --timestamping to fetch files if they have changed, but githubusercontent does not check if-modified-since
    wget --no-directories --timestamping --max-redirect=0 -P "$ASSETS_DIR" "$ASSET";
  fi;
  if [ ! -f "$FILE.gz" ] || [ "$FILE" -nt "$FILE.gz" ]; then
    rm "$FILE.gz" || true;
    compress_gzip_static "$FILE";
  fi;
done;

sudo chown -R root:nginx "$INSTALL_TEMP_DIR" "$ASSETS_DIR";

# Remove existing site if found and move new site in place
sudo rm -r "$INSTALL_DIR" || true;
sudo mv "$INSTALL_TEMP_DIR" "$INSTALL_DIR";
