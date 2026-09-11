#!/usr/bin/env bash
# Launches the Hesai driver + RViz2. Run as your NORMAL user (no sudo).
#   bash /home/hao/Work/ros/run_hesai.sh
set -euo pipefail

WS="/home/hao/Work/ros/hesai_ws"

# Same conda hygiene as the build.
PATH="$(echo "$PATH" | tr ':' '\n' | grep -v -E 'conda' | paste -sd: -)"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
unset PYTHONPATH CONDA_PREFIX CONDA_DEFAULT_ENV || true

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

echo "==> Launching hesai_ros_driver + RViz2 ..."
echo "    point cloud topic: /lidar_points   frame: hesai_lidar"
exec ros2 launch hesai_ros_driver start.py
