#!/usr/bin/env bash
# Installs ROS 2 Jazzy (desktop, incl. RViz2) + build deps for the Hesai Pandar QT64 driver.
# Target: Ubuntu 24.04 "noble", x86_64.
# Run with:  sudo bash /home/hao/Work/ros/install_ros2_hesai.sh
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run me with sudo:  sudo bash $0" >&2
  exit 1
fi

# Never let a conda env leak into apt/dpkg's view of python.
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export DEBIAN_FRONTEND=noninteractive

CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
echo "==> Ubuntu codename: $CODENAME"

echo "==> [0/7] Reclaim disk space (apt cache + journal)"
df -h --output=avail / | tail -1 | xargs echo "    free before:"
apt-get clean
journalctl --vacuum-size=200M >/dev/null 2>&1 || true
df -h --output=avail / | tail -1 | xargs echo "    free after: "

# ROS 2 desktop + PCL/Boost dev + the colcon build need roughly 8 GB.
AVAIL_MB=$(df --output=avail -m / | tail -1 | tr -d ' ')
if (( AVAIL_MB < 9000 )); then
  echo "ERROR: only ${AVAIL_MB} MB free on /. Need ~9000 MB. Free more space first." >&2
  exit 1
fi

echo "==> [1/7] Locale (ROS 2 needs a UTF-8 locale)"
apt-get update
apt-get install -y locales curl gnupg software-properties-common
locale-gen en_US en_US.UTF-8
update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

echo "==> [2/7] Enable the 'universe' repository"
add-apt-repository -y universe

echo "==> [3/7] Add the ROS 2 apt source"
ROS_APT_SOURCE_VERSION="$(curl -sSL https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest \
  | grep -F '"tag_name"' | awk -F'"' '{print $4}')"
: "${ROS_APT_SOURCE_VERSION:=1.3.0}"
echo "    ros-apt-source version: $ROS_APT_SOURCE_VERSION"
curl -fsSL -o /tmp/ros2-apt-source.deb \
  "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.${CODENAME}_all.deb"
apt-get install -y /tmp/ros2-apt-source.deb
apt-get update

echo "==> [4/7] Install ROS 2 Jazzy desktop (this is the big one, ~2-4 GB)"
apt-get install -y ros-jazzy-desktop ros-dev-tools

echo "==> [5/7] Install Hesai driver build dependencies"
apt-get install -y \
  build-essential cmake git \
  libboost-all-dev \
  libyaml-cpp-dev \
  libpcl-dev \
  libpcap-dev \
  libssl-dev openssl \
  python3-colcon-common-extensions

echo "==> [6/7] Verify"
set +u; source /opt/ros/jazzy/setup.bash; set -u
echo "    ROS_DISTRO = ${ROS_DISTRO:-<unset>}"
command -v rviz2 && echo "    rviz2 OK"
command -v ros2  && echo "    ros2 OK"

echo
echo "=== DONE. ROS 2 Jazzy installed. ==="
echo "Next (as your normal user, NOT root):"
echo "    bash /home/hao/Work/ros/build_hesai.sh"
