#!/usr/bin/env bash
# Launch the Hesai driver + RViz2. Run as a NORMAL user (no sudo).
#   bash hesai_qt64/run.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="$HERE/ws"

# --- Refuse to start a second instance ------------------------------------
# Two drivers both bind UDP 2368 with SO_REUSEPORT and both publish to
# /lidar_points, which doubles the load into RViz. The node ignores SIGTERM
# while blocked in recv, so use -9. Match the exact process name (-x; comm is
# truncated to 'hesai_ros_drive') rather than -f: a -f pattern also matches any
# shell whose command line mentions it, so `pkill -f` can kill your own terminal.
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
# locators on the LiDAR NIC. With the default SUBNET range it does, and then any
# change to that interface - notably an `ip addr flush` - invalidates the
# locators: RViz silently stops receiving while the driver keeps reading its
# 0.0.0.0:2368 socket and printing frames, so the cloud appears to freeze for no
# reason. LOCALHOST keeps ROS traffic on loopback/shared memory, immune to that.
# Set ROS_DISCOVERY=SUBNET to view the cloud from another machine.
export ROS_AUTOMATIC_DISCOVERY_RANGE="${ROS_DISCOVERY:-LOCALHOST}"

if [[ ! -f "$WS/install/setup.bash" ]]; then
  echo "ERROR: workspace not built. Run: bash $HERE/build.sh" >&2
  exit 1
fi
set +u
source /opt/ros/jazzy/setup.bash
source "$WS/install/setup.bash"
set -u

# Launched from an SSH / VS Code shell there is no DISPLAY, but the machine may
# still have a local desktop session on :0 - point RViz at it.
if [[ -z "${DISPLAY:-}" ]]; then
  export DISPLAY=:0
  [[ -r /run/user/$(id -u)/gdm/Xauthority ]] && export XAUTHORITY=/run/user/$(id -u)/gdm/Xauthority
  echo "==> DISPLAY was unset; using $DISPLAY"
fi

echo "==> discovery range: $ROS_AUTOMATIC_DISCOVERY_RANGE"
echo "==> Launching hesai_ros_driver + RViz2 ..."
echo "    point cloud topic: /lidar_points   frame: hesai_lidar"
exec ros2 launch hesai_ros_driver start.py
