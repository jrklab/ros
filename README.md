# Pandar QT64 live point cloud on ROS 2

Scripts to install, build, and run a live point-cloud visualization for a
**Hesai Pandar QT64** LiDAR on **Ubuntu 24.04 + ROS 2 Jazzy**, using Hesai's
official driver and RViz2. No custom driver code.

Verified working: 76,800 points/frame (64 ch × 1200 az) at 10 Hz, 0 packet loss.

## Requirements

- Ubuntu 24.04 (noble), x86_64
- A **gigabit Ethernet** port. A USB 3.0 adapter is fine (tested: ASIX AX88179).
  100 Mb/s links work but leave little headroom.
- Pandar QT64 powered through its interface box

## Setup

```bash
git clone <this-repo> ~/Work/ros && cd ~/Work/ros

# 1. ROS 2 Jazzy desktop + build deps. Needs ~9 GB free.
sudo bash install_ros2_hesai.sh

# 2. Clone + build the Hesai driver (clones on first run)
bash build_hesai.sh

# 3. Configure the NIC for the LiDAR. Re-run after each reboot/replug.
sudo bash setup_lidar_net.sh

# 4. Launch driver + RViz2
bash run_hesai.sh
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

Config lives in `hesai_ws/src/HesaiLidar_ROS_2.0/config/config.yaml`. Stock
defaults already match a factory QT64 — no edits needed for a first run. The
driver pulls the per-unit angle-correction file off the sensor over PTC, so no
calibration file is required.

Override the network with env vars:

```bash
sudo LIDAR_IP=192.168.5.201 HOST_IP=192.168.5.100 bash setup_lidar_net.sh
```

## Verify

```bash
source /opt/ros/jazzy/setup.bash
source hesai_ws/install/setup.bash

ros2 topic hz   /lidar_points            # expect ~10 Hz
ros2 topic info /lidar_points            # 1 publisher
ros2 topic echo /lidar_packets_loss --once   # loss count should stay 0
```

Driver-independent check that the sensor is transmitting at all:

```bash
sudo tcpdump -i <iface> -n udp port 2368 -c 5
# or, without root, watch the NIC counters:
cat /sys/class/net/<iface>/statistics/rx_packets
```

## Stop / restart

```bash
pkill -9 -x hesai_ros_drive; pkill -9 -x rviz2
bash run_hesai.sh
```

Match on the exact process name (`-x`), not `-f`. The driver's `comm` is
truncated to `hesai_ros_drive`, and a `-f` pattern also matches any shell whose
command line mentions it — `pkill -f hesai_ros_driver_node` can kill your own
terminal. `-9` is needed because the node ignores `SIGTERM` while blocked in its
receive loop.

`run_hesai.sh` refuses to start if an instance is already running: two drivers
both bind UDP 2368 via `SO_REUSEPORT`, both publish to `/lidar_points`, and the
doubled rate overwhelms RViz.

## Gotchas

- **Never run `setup_lidar_net.sh` while the visualization is up.** It used to
  `ip addr flush` the interface, deleting the address ROS 2's DDS had bound its
  locators to. RViz stops receiving and the cloud freezes, while the driver —
  whose socket is bound to `0.0.0.0:2368` — keeps reading and printing frames,
  so it looks like RViz hung for no reason. The script now refuses to run when
  the driver or RViz is alive, and no longer flushes an already-correct address.
  `run_hesai.sh` also pins `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST` so ROS
  traffic stays on loopback and is immune to the LiDAR NIC entirely. Set
  `ROS_DISCOVERY=SUBNET` if you need to view the cloud from another machine.
- **`setup_lidar_net.sh` is not persistent.** Re-run it after a reboot or replug.
- **Subnet collision.** The QT64 ships on `192.168.1.x`, which many home LANs
  also use. The script pins a `/32` host route to the wired NIC so Wi-Fi does not
  steal the traffic. Cleaner fix: move the LiDAR to its own subnet via its web UI.
- **conda breaks the build.** If `~/miniconda3` is ahead of `/usr/bin` in `PATH`,
  colcon links against conda's Python/Boost/yaml-cpp. `build_hesai.sh` and
  `run_hesai.sh` strip conda themselves — use them rather than a bare `colcon build`.
- **LiDAR clock.** Without PTP/GPS the sensor stamps messages from its power-on
  default (a 2017 epoch). Harmless for RViz; set `use_timestamp_type: 1` in
  `config.yaml` to use host receive time instead for rosbag/TF work.
- **No `DISPLAY`.** `run_hesai.sh` falls back to `:0` so it works over SSH.

See [NOTES.md](NOTES.md) for the full reasoning and machine-specific findings.
