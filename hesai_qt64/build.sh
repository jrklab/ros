#!/usr/bin/env bash
# Clone (if needed) and build the Hesai ROS 2 driver. Run as a NORMAL user.
#   bash hesai_qt64/build.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="$HERE/ws"

# --- Keep conda out of the build -----------------------------------------
# If a conda install sits ahead of /usr/bin in PATH, colcon picks up conda's
# python, cmake, Boost and yaml-cpp and links against them, then fails mid-build
# or produces a binary that breaks at runtime against the ROS ones.
PATH="$(echo "$PATH" | tr ':' '\n' | grep -v -E 'conda' | paste -sd: -)"
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
  echo "ERROR: ROS 2 Jazzy not found. Run setup/install_ros2_jazzy.sh first." >&2
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
echo "Next:  sudo bash $HERE/setup_net.sh   then   bash $HERE/run.sh"
