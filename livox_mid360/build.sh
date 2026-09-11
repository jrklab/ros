#!/usr/bin/env bash
# Clone (if needed) and build Livox-SDK2 + livox_ros_driver2. Run as a NORMAL
# user; it will ask for sudo only to install the SDK into /usr/local.
#   bash livox_mid360/build.sh
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

# --- Fetch upstream if not here yet ---------------------------------------
SDK="$WS/src/Livox-SDK2"
DRIVER="$WS/src/livox_ros_driver2"
mkdir -p "$WS/src"
if [[ ! -d "$SDK" ]]; then
  echo "==> Cloning Livox-SDK2 ..."
  git clone --depth 1 https://github.com/Livox-SDK/Livox-SDK2.git "$SDK"
else
  echo "==> Livox-SDK2 already present at $SDK"
fi
if [[ ! -d "$DRIVER" ]]; then
  echo "==> Cloning livox_ros_driver2 ..."
  git clone --depth 1 https://github.com/Livox-SDK/livox_ros_driver2.git "$DRIVER"
else
  echo "==> livox_ros_driver2 already present at $DRIVER"
fi

# --- Source ROS ------------------------------------------------------------
if [[ ! -f /opt/ros/jazzy/setup.bash ]]; then
  echo "ERROR: ROS 2 Jazzy not found. Run setup/install_ros2_jazzy.sh first." >&2
  exit 1
fi
set +u; source /opt/ros/jazzy/setup.bash; set -u
echo "==> ROS_DISTRO = $ROS_DISTRO"

# --- Build + install the SDK (livox_ros_driver2 links against it from
# /usr/local, there is no way to point it at an in-tree build) -------------
echo "==> Building Livox-SDK2 ..."
mkdir -p "$SDK/build"
cd "$SDK/build"
# The vendored CMakeLists.txt predates CMake 4; -DCMAKE_POLICY_VERSION_MINIMUM
# restores the old policy set instead of patching upstream's file.
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5
make -j"$(nproc)"
echo "==> Installing Livox-SDK2 to /usr/local (needs sudo) ..."
sudo make install
sudo ldconfig

# --- Build the ROS 2 driver -------------------------------------------------
# Upstream's own build.sh swaps in the ROS2 package.xml/CMakeLists.txt and
# invokes colcon on the whole workspace; run it in place rather than
# reimplementing that dance.
echo "==> Building livox_ros_driver2 ..."
cd "$DRIVER"
./build.sh jazzy

echo
echo "=== BUILD OK ==="
echo "Next:  sudo bash $HERE/setup_net.sh   then   bash $HERE/run.sh"
