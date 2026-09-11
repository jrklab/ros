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
pkill -f hesai_ros_driver_node; pkill -f rviz2
bash run_hesai.sh
```

The driver ignores `SIGTERM` while blocked in its receive loop; use `pkill -9`
if it lingers. A leftover instance double-publishes `/lidar_points`.

## Gotchas

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
