#!/usr/bin/env bash
# Builds the Hesai ROS 2 driver workspace. Run as your NORMAL user (no sudo).
#   bash /home/hao/Work/ros/build_hesai.sh
set -euo pipefail

WS="/home/hao/Work/ros/hesai_ws"

# --- Keep miniconda out of the build -------------------------------------
# This machine has ~/miniconda3 ahead of /usr/bin in PATH. Conda ships its own
# python3, cmake, and libstdc++/boost/yaml-cpp, and colcon will happily link
# against them and then fail at runtime (or mid-build) against the ROS ones.
PATH="$(echo "$PATH" | tr ':' '\n' | grep -v -E 'conda|/home/hao/\.local/bin' | paste -sd: -)"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
unset PYTHONPATH CONDA_PREFIX CONDA_DEFAULT_ENV CONDA_EXE CONDA_PYTHON_EXE || true

echo "==> python3: $(command -v python3)   ($(python3 --version 2>&1))"
echo "==> cmake:   $(command -v cmake)     ($(cmake --version | head -1))"
case "$(command -v python3)" in
  *conda*) echo "ERROR: conda python still in PATH, aborting." >&2; exit 1;;
esac

# --- Fetch the upstream driver if it is not here yet ----------------------
DRIVER="$WS/src/HesaiLidar_ROS_2.0"
if [[ ! -d "$DRIVER" ]]; then
  echo "==> Cloning HesaiLidar_ROS_2.0 (+ SDK submodule) ..."
  mkdir -p "$WS/src"
  git clone --recurse-submodules --depth 1 \
    https://github.com/HesaiTechnology/HesaiLidar_ROS_2.0.git "$DRIVER"
else
  echo "==> Driver already present at $DRIVER"
fi

# --- Source ROS ----------------------------------------------------------
if [[ ! -f /opt/ros/jazzy/setup.bash ]]; then
  echo "ERROR: ROS 2 Jazzy not found. Run install_ros2_hesai.sh first." >&2
  exit 1
fi
set +u; source /opt/ros/jazzy/setup.bash; set -u
echo "==> ROS_DISTRO = $ROS_DISTRO"

# --- Build ---------------------------------------------------------------
cd "$WS"
echo "==> Building in $WS ..."
colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release

echo
echo "=== BUILD OK ==="
echo "To run:  bash /home/hao/Work/ros/run_hesai.sh"
