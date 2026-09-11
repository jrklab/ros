#!/usr/bin/env bash
# Launch the Livox driver + RViz2. Run as a NORMAL user (no sudo).
#   bash livox_mid360/run.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="$HERE/ws"

# --- Refuse to start a second instance ------------------------------------
# Match the exact process name (-x; comm is truncated to 'livox_ros_drive')
# rather than -f: a -f pattern also matches any shell whose command line
# mentions it, so `pkill -f` can kill your own terminal.
# A defunct (zombie) entry is already dead and holds no socket - pkill can't
# touch it and it isn't a real second instance, so skip it automatically
# instead of blocking the launch; it'll be reaped once its parent waits on it.
live_pids="$(pgrep -x livox_ros_drive | while read -r pid; do
  state="$(ps -o stat= -p "$pid" 2>/dev/null | tr -d ' ')" || continue
  [[ "${state:0:1}" != "Z" ]] && echo "$pid"
done || true)"
if [[ -n "$live_pids" ]]; then
  echo "ERROR: a livox_ros_driver2_node is already running:" >&2
  ps -o pid,stat,cmd -p $live_pids | sed 's/^/  /' >&2
  echo "Stop it first:  pkill -9 -x livox_ros_drive; pkill -9 -x rviz2" >&2
  exit 1
fi

# --- Keep conda out of the runtime ----------------------------------------
PATH="$(echo "$PATH" | tr ':' '\n' | grep -v -E 'conda' | paste -sd: -)"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
unset PYTHONPATH CONDA_PREFIX CONDA_DEFAULT_ENV || true

# --- Confine DDS to this machine ------------------------------------------
# Same reasoning as hesai_qt64/run.sh: keep ROS 2's own DDS traffic off the
# G1's Ethernet NIC so an address change on that link (e.g. NetworkManager
# fighting the static IP, see setup_net.sh) can't freeze RViz.
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
echo "==> config: $HERE/config/MID360_config.json"
echo "==> Launching livox_ros_driver2 + RViz2 ..."
echo "    point cloud topic: /livox/lidar   frame: livox_frame"
# Extra args pass through, e.g.  bash run.sh rviz:=false
exec ros2 launch "$HERE/launch/mid360.launch.py" "$@"
