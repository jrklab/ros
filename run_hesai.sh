#!/usr/bin/env bash
# Launches the Hesai driver + RViz2. Run as your NORMAL user (no sudo).
#   bash /home/hao/Work/ros/run_hesai.sh
set -euo pipefail

WS="/home/hao/Work/ros/hesai_ws"

# --- Refuse to start a second instance ------------------------------------
# Two drivers both bind UDP 2368 with SO_REUSEPORT and both publish to
# /lidar_points, which doubles the load on RViz and corrupts the packet-loss
# counters. The node ignores SIGTERM while blocked in recv, so use -9.
if pgrep -x hesai_ros_drive >/dev/null; then
  echo "ERROR: a hesai_ros_driver_node is already running:" >&2
  pgrep -ax hesai_ros_drive | sed 's/^/  /' >&2
  echo "Stop it first:  pkill -9 -x hesai_ros_drive; pkill -9 -x rviz2" >&2
  exit 1
fi

# --- Keep conda out of the runtime ----------------------------------------
PATH="$(echo "$PATH" | tr ':' '\n' | grep -v -E 'conda' | paste -sd: -)"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
unset PYTHONPATH CONDA_PREFIX CONDA_DEFAULT_ENV || true

# --- Confine DDS to this machine ------------------------------------------
# The driver and RViz are both local, so there is no reason for DDS to bind
# locators on the LiDAR NIC. With the default SUBNET range it does, and then
# ANY change to that interface - notably the `ip addr flush` in
# setup_lidar_net.sh - invalidates the locators and RViz silently stops
# receiving while the driver keeps reading its UDP socket and printing frames.
# LOCALHOST keeps ROS traffic on loopback/shared memory, immune to all that.
# Override with ROS_DISCOVERY=SUBNET to view the cloud from another machine.
export ROS_AUTOMATIC_DISCOVERY_RANGE="${ROS_DISCOVERY:-LOCALHOST}"

set +u
source /opt/ros/jazzy/setup.bash
source "$WS/install/setup.bash"
set -u

# If launched from an SSH / VS Code shell there is no DISPLAY, but the machine
# does have a desktop session on :0 - point RViz at it.
if [[ -z "${DISPLAY:-}" ]]; then
  export DISPLAY=:0
  [[ -r /run/user/$(id -u)/gdm/Xauthority ]] && export XAUTHORITY=/run/user/$(id -u)/gdm/Xauthority
  echo "==> DISPLAY was unset; using $DISPLAY"
fi

echo "==> discovery range: $ROS_AUTOMATIC_DISCOVERY_RANGE"
echo "==> Launching hesai_ros_driver + RViz2 ..."
echo "    point cloud topic: /lidar_points   frame: hesai_lidar"
exec ros2 launch hesai_ros_driver start.py
