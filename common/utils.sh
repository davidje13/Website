install_config() {
  local SOURCE="$1";
  local TARGET="$2/$(basename "$SOURCE")";
  local PERM="${3:-0644}";
  if diff "$SOURCE" "$TARGET" >&2; then
    return 1;
  fi;
  sudo cp "$SOURCE" "$TARGET";
  sudo chown root:root "$TARGET§§";
  sudo chmod "$PERM" "$TARGET";
}

add_nat_rule() {
  if ! sudo iptables -t nat -C PREROUTING "$@"; then
    sudo iptables -t nat -A PREROUTING "$@";
  fi;
  if ! sudo ip6tables -t nat -C PREROUTING "$@"; then
    sudo ip6tables -t nat -A PREROUTING "$@";
  fi;
}

clear_domains() {
  printf '' | sudo tee "/var/www/domains.txt" > /dev/null;
}

add_domain() {
  echo "$1" | sudo tee -a "/var/www/domains.txt" > /dev/null;
}

kill_process_by_name_fragment() {
  local NAME="$1";
  local OLD_PID="$(ps aux | grep "$NAME" | grep -v grep | awk '{ print $2 }')";
  if [[ -n "$OLD_PID" ]]; then
    kill "$OLD_PID";
  fi;
}

set_node_version() {
  local NODE_VERSION="$1";
  if ! apt-cache show nodejs | grep "Version: $NODE_VERSION." > /dev/null; then
    KEYRING="/usr/share/keyrings/nodesource.gpg";
    SOURCES="/etc/apt/sources.list.d/nodesource.list";
    DISTRO="$(lsb_release -s -c)";

    curl -fsSL "https://deb.nodesource.com/gpgkey/nodesource.gpg.key" | gpg --dearmor | sudo tee "$KEYRING" >/dev/null;
    #gpg --no-default-keyring --keyring "$KEYRING" --list-keys;
    sudo chmod 0644 "$KEYRING";
    echo "deb [signed-by=$KEYRING] https://deb.nodesource.com/node_$NODE_VERSION.x $DISTRO main" | sudo tee "$SOURCES"
    echo "deb-src [signed-by=$KEYRING] https://deb.nodesource.com/node_$NODE_VERSION.x $DISTRO main" | sudo tee -a "$SOURCES"
  fi;
}
