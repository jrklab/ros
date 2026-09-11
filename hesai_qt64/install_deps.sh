#!/usr/bin/env bash
# Build dependencies for Hesai's HesaiLidar_ROS_2.0 driver + its SDK.
#   sudo bash hesai_qt64/install_deps.sh
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run me with sudo:  sudo bash $0" >&2
  exit 1
fi
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export DEBIAN_FRONTEND=noninteractive

echo "==> Installing Hesai driver dependencies"
apt-get update
apt-get install -y \
  libboost-all-dev \
  libyaml-cpp-dev \
  libpcl-dev \
  libpcap-dev \
  libssl-dev openssl

echo
echo "=== Done. Next:  bash hesai_qt64/build.sh ==="
