#!/usr/bin/env bash
# Build dependencies for Livox-SDK2 + livox_ros_driver2.
#   sudo bash livox_mid360/install_deps.sh
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run me with sudo:  sudo bash $0" >&2
  exit 1
fi
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export DEBIAN_FRONTEND=noninteractive

echo "==> Installing Livox driver dependencies"
apt-get update
apt-get install -y \
  libpcl-dev \
  libeigen3-dev \
  libapr1-dev \
  ros-jazzy-pcl-conversions \
  ros-jazzy-pcl-msgs

echo
echo "=== Done. Next:  bash livox_mid360/build.sh ==="
