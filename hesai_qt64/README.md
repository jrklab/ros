# Hesai Pandar QT64 — live point cloud in RViz2

Install, build, and run a live point-cloud visualization for a **Hesai Pandar
QT64** on **Ubuntu 24.04 + ROS 2 Jazzy**, using Hesai's official driver. No
custom driver code.

Verified on hardware: 76,800 points/frame (64 channels × 1200 azimuth) at
10 Hz, 0 packet loss.

## Why these pieces

| | |
|---|---|
| **ROS 2 Jazzy** | The distro paired with Ubuntu 24.04. ROS 1 Noetic is EOL and 20.04-only. |
| **[HesaiLidar_ROS_2.0](https://github.com/HesaiTechnology/HesaiLidar_ROS_2.0)** | Hesai's own driver. Its model table lists `PandarQT` (the QT64 family) and its distro table lists Jazzy/24.04. |
| **RViz2** | Ships with `ros-jazzy-desktop`. The driver's `launch/start.py` already starts it with a preconfigured display. |

The driver is cloned by `build.sh` rather than vendored here, so its history and
SDK submodule stay upstream.

## Requirements

- Ubuntu 24.04 (noble), x86_64
- A **gigabit Ethernet** port. A USB 3.0 adapter works (tested: ASIX AX88179).
  A 100 Mb/s link carries the ~26 Mb/s single-return stream but leaves little
  headroom — dual return roughly doubles it.
- QT64 powered through its interface box

## Setup

```bash
# 1. ROS 2 Jazzy desktop (skip if already installed). Needs ~9 GB free.
sudo bash ../setup/install_ros2_jazzy.sh

# 2. Driver build dependencies
sudo bash install_deps.sh

# 3. Clone + build the driver
bash build.sh

# 4. Configure the NIC. Re-run after each reboot/replug.
sudo bash setup_net.sh

# 5. Launch driver + RViz2
bash run.sh
```

RViz2 opens preconfigured: `PointCloud2` on `/lidar_points`, fixed frame
`hesai_lidar`, colored by intensity.

## Defaults

| | |
|---|---|
| LiDAR IP | `192.168.1.201` |
| Host IP | `192.168.1.100` |
| Point cloud | UDP `2368` |
| PTC (control + calibration) | TCP `9347` |
| Web UI | `http://192.168.1.201` |
| Topic / frame | `/lidar_points` / `hesai_lidar` |

Config is tracked in this repo at [`config/qt64.yaml`](config/qt64.yaml), and
`run.sh` points the driver at it via the node's `config_path` parameter using
[`launch/qt64.launch.py`](launch/qt64.launch.py). Upstream's `start.py` instead
reads the copy inside the driver's installed share directory, which lives in the
gitignored workspace — edits there are untracked and lost on a re-clone.

Defaults already match a factory QT64, so no edits are needed for a first run.
The driver pulls the per-unit angle-correction file off the sensor over PTC, so
no calibration file is required. The model is auto-detected; there is no
`lidar_type` to set.

`run.sh` passes extra arguments through to the launch file:

```bash
bash run.sh rviz:=false                    # driver only, no GUI
bash run.sh config:=/path/to/other.yaml    # a different config
```

Move the LiDAR to its own subnet (recommended if `192.168.1.x` is already in use)
via its web UI, then:

```bash
sudo LIDAR_IP=192.168.5.201 HOST_IP=192.168.5.100 bash setup_net.sh
```
and set `device_ip_address` to match in `config.yaml`.

## Verify

```bash
source /opt/ros/jazzy/setup.bash
source ws/install/setup.bash
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST   # run.sh sets this; match it

ros2 topic info /lidar_points                  # 1 publisher, 1 subscriber
ros2 topic echo /lidar_packets_loss --once     # loss should stay 0
```

Driver-independent check that the sensor is transmitting, before ROS is involved:

```bash
sudo tcpdump -i <iface> -n udp port 2368 -c 5
# or without root, watch the NIC counters climb:
cat /sys/class/net/<iface>/statistics/rx_packets
```

If the NIC counters climb but nothing reaches a socket, the interface has no IP —
the kernel drops the frames before any socket sees them. Run `setup_net.sh`.

## Stop / restart

```bash
pkill -9 -x hesai_ros_drive; pkill -9 -x rviz2
bash run.sh
```

Match on the exact process name (`-x`), not `-f`. The driver's `comm` is
truncated to `hesai_ros_drive`, and a `-f` pattern also matches any shell whose
command line mentions it — `pkill -f hesai_ros_driver_node` can kill your own
terminal. `-9` is needed because the node ignores `SIGTERM` while blocked in its
receive loop.

## Gotchas

- **Never run `setup_net.sh` while the visualization is up.** Flushing the
  interface deletes the address ROS 2's DDS bound its locators to. RViz stops
  receiving and the cloud freezes, while the driver — bound to `0.0.0.0:2368` —
  keeps reading and printing frames, so it looks like RViz hung for no reason.
  The script now refuses to run when the driver or RViz is alive, and skips the
  flush when the address is already correct. `run.sh` also pins
  `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST` so ROS traffic stays on loopback and
  is immune to the LiDAR NIC. Set `ROS_DISCOVERY=SUBNET` for remote viewing.
- **Only one driver at a time.** Two instances both bind UDP 2368 via
  `SO_REUSEPORT` and both publish to `/lidar_points`, doubling the load into
  RViz. `run.sh` refuses to start a second one.
- **`setup_net.sh` is not persistent.** Re-run after a reboot or replug.
- **Subnet collision.** The QT64 ships on `192.168.1.x`, which many LANs also
  use. The script pins a `/32` host route to the wired NIC so another interface
  on the same subnet cannot steal the traffic, and relaxes `rp_filter`.
- **conda breaks the build.** If a conda install sits ahead of `/usr/bin` in
  `PATH`, colcon links against conda's Python/Boost/yaml-cpp. `build.sh` and
  `run.sh` strip conda themselves — use them rather than a bare `colcon build`.
- **LiDAR clock.** Without PTP/GPS the sensor stamps messages from its power-on
  default (a 2017 epoch). Harmless for RViz, since the cloud's `frame_id`
  matches the fixed frame and no TF lookup is needed. Set
  `use_timestamp_type: 1` in `config.yaml` to use host receive time instead for
  rosbag/TF work.
- **No `DISPLAY`.** `run.sh` falls back to `:0`, so it works over SSH when the
  machine has a local desktop session.
- **`[FATAL] load firetime error` on every start is expected on a QT64, and
  harmless.** In the SDK's `libhesai/Lidar/lidar.h`, only `ATX` and
  `PandarQT128` try to fetch firetimes from the sensor before falling back to a
  file; every other model — including `PandarQT` — calls `LoadFiretimesFile()`
  unconditionally with no empty-path guard. An empty path fails to open, throws,
  and is logged as FATAL. No config value silences it: `""` triggers it and so
  does a bogus path. The handler then sets `get_firetime_file_ = false` and
  returns, which disables a small per-laser azimuth correction. Point output is
  otherwise unaffected — verified at 10 Hz with 0 packet loss. Supply a real
  firetimes CSV from the sensor's web UI if you need that last bit of angular
  precision.

## No LiDAR handy?

Set `source_type: 2` in `config.yaml` and point `pcap_type.pcap_path` at a QT64
capture, with `correction_file_path` at that unit's correction csv. That
exercises ROS, the driver, and RViz end to end without hardware.
