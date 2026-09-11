#!/usr/bin/env bash
# Install ROS 2 Jazzy Jalisco (desktop, includes RViz2) on Ubuntu 24.04.
# Generic - no project-specific packages. Run per-project dependency scripts after.
#
#   sudo bash setup/install_ros2_jazzy.sh
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run me with sudo:  sudo bash $0" >&2
  exit 1
fi

# A conda install ahead of /usr/bin must not shape apt/dpkg's view of python.
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export DEBIAN_FRONTEND=noninteractive

CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
if [[ "$CODENAME" != "noble" ]]; then
  echo "WARNING: this targets Ubuntu 24.04 (noble); found '$CODENAME'." >&2
fi
echo "==> Ubuntu codename: $CODENAME"

echo "==> [0/6] Reclaim disk space (apt cache + journal)"
apt-get clean
journalctl --vacuum-size=200M >/dev/null 2>&1 || true

# ROS 2 desktop plus a typical colcon build needs roughly 8 GB.
AVAIL_MB=$(df --output=avail -m / | tail -1 | tr -d ' ')
echo "    free on /: ${AVAIL_MB} MB"
if (( AVAIL_MB < 9000 )); then
  echo "ERROR: only ${AVAIL_MB} MB free on /. Need ~9000 MB. Free more space first." >&2
  exit 1
fi

echo "==> [1/6] Locale (ROS 2 needs a UTF-8 locale)"
apt-get update
apt-get install -y locales curl gnupg software-properties-common
locale-gen en_US en_US.UTF-8
update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

echo "==> [2/6] Enable the 'universe' repository"
add-apt-repository -y universe

echo "==> [3/6] Add the ROS 2 apt source"
ROS_APT_SOURCE_VERSION="$(curl -sSL https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest \
  | grep -F '"tag_name"' | awk -F'"' '{print $4}')"
: "${ROS_APT_SOURCE_VERSION:=1.3.0}"
echo "    ros-apt-source version: $ROS_APT_SOURCE_VERSION"
curl -fsSL -o /tmp/ros2-apt-source.deb \
  "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.${CODENAME}_all.deb"
apt-get install -y /tmp/ros2-apt-source.deb
apt-get update

echo "==> [4/6] Install ROS 2 Jazzy desktop (~2-4 GB)"
apt-get install -y ros-jazzy-desktop ros-dev-tools

echo "==> [5/6] Common build tooling"
apt-get install -y build-essential cmake git python3-colcon-common-extensions

echo "==> [6/6] Verify"
set +u; source /opt/ros/jazzy/setup.bash; set -u
echo "    ROS_DISTRO = ${ROS_DISTRO:-<unset>}"
command -v rviz2 >/dev/null && echo "    rviz2 OK"
command -v ros2  >/dev/null && echo "    ros2 OK"

echo
echo "=== ROS 2 Jazzy installed. ==="
echo "Next: install a project's dependencies, e.g."
echo "    sudo bash hesai_qt64/install_deps.sh"
