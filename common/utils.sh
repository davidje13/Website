install_config() {
  local SOURCE="$1";
  local TARGET="$2/$(basename "$SOURCE")";
  local PERM="${3:-0644}";
  if diff "$SOURCE" "$TARGET" >&2; then
    return 1;
  fi;
  sudo cp "$SOURCE" "$TARGET";
  sudo chown root:root "$TARGET";
  sudo chmod "$PERM" "$TARGET";
}

kill_process_by_name_fragment() {
  local NAME="$1";
  local OLD_PID="$(ps -A -o pid -o command | awk 'index($0, "'"$NAME"'") && $2 != "awk" { print $1 }')"
  if [ -n "$OLD_PID" ]; then
    kill "$OLD_PID";
  fi;
}

set_node_version() {
  local NODE_VERSION="$1";
  local KEYRING="/etc/apt/keyrings/nodesource.gpg";
  local SOURCES="/etc/apt/sources.list.d/nodesource.list";
  local PIN="/etc/apt/preferences.d/nodesource-pin";

  if ! [ -f "$SOURCES" ] || ! grep "node_$NODE_VERSION." "$SOURCES" > /dev/null; then
    curl -fsSL "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" | sudo gpg --dearmor -o "$KEYRING";
    #gpg --no-default-keyring --keyring "$KEYRING" --list-keys;
    echo "deb [arch=$(dpkg --print-architecture) signed-by=$KEYRING] https://deb.nodesource.com/node_$NODE_VERSION.x nodistro main" | sudo tee "$SOURCES" >/dev/null;
    printf 'Package: nodejs\nPin: origin deb.nodesource.com\nPin-Priority: 600\n' | sudo tee "$PIN" >/dev/null;
  fi;
}

set_nginx_repo() {
  local KEYRING="/etc/apt/keyrings/nginx.gpg";
  local SOURCES="/etc/apt/sources.list.d/nginx.list";
  local PIN="/etc/apt/preferences.d/nginx-pin";

  if ! [ -f "$SOURCES" ]; then
    curl -fsSL "https://nginx.org/keys/nginx_signing.key" | sudo gpg --dearmor -o "$KEYRING";
    echo "deb [signed-by=$KEYRING] http://nginx.org/packages/debian $(lsb_release -sc) nginx" | sudo tee "$SOURCES" >/dev/null;
    printf 'Package: nginx\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n' | sudo tee "$PIN" >/dev/null;
  fi;
}

set_mongodb_version() {
  # MongoDB is not available for Debian ARM (https://www.mongodb.com/try/download/community-edition/releases)
  # Request to add it from several years ago: https://feedback.mongodb.com/forums/924280-database/suggestions/46410079-arm-support
  # So for now we need to stick to Intel - maybe switch from Mongo to NodeJS's built-in SQLite later to be able to use ARM for cost savings

  local MONGO_VERSION="$1";
  local KEYRING="/etc/apt/keyrings/mongodb-org.gpg";
  local SOURCES="/etc/apt/sources.list.d/mongodb-org.list";

  . /usr/lib/os-release; # load VERSION_CODENAME variable

  if ! [ -f "$SOURCES" ] || ! grep "mongodb-org/$MONGO_VERSION " "$SOURCES" > /dev/null; then
    curl -fsSL "https://www.mongodb.org/static/pgp/server-$MONGO_VERSION.asc" | sudo gpg --dearmor -o "$KEYRING";
    echo "deb [signed-by=$KEYRING] https://repo.mongodb.org/apt/debian $VERSION_CODENAME/mongodb-org/$MONGO_VERSION main" | sudo tee "$SOURCES" >/dev/null;
  fi;
}
