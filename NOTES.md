# Pandar QT64 live point cloud on ROS 2

## What was chosen and why

| | |
|---|---|
| ROS | **ROS 2 Jazzy Jalisco** — the distro that pairs with Ubuntu 24.04. ROS 1 Noetic is EOL and 20.04-only, so it is not an option here. |
| Driver | **[HesaiLidar_ROS_2.0](https://github.com/HesaiTechnology/HesaiLidar_ROS_2.0)** — Hesai's own driver. Its model table lists `PandarQT` (that is the QT64 family) and its distro table lists Jazzy/24.04. No custom code was written. |
| Viewer | **RViz2**, included in `ros-jazzy-desktop`. The driver's `launch/start.py` already starts RViz2 with `rviz/rviz2.rviz`, preconfigured for PointCloud2 on `/lidar_points`, fixed frame `hesai_lidar`, intensity coloring. |

Cloned to `hesai_ws/src/HesaiLidar_ROS_2.0` (with the `HesaiLidar_SDK_2.0` submodule).

## Three things about this machine that affect the setup

### 1. There is no Ethernet port — this blocks live data
`lspci` shows only a Realtek RTL8822CE **Wi-Fi** adapter. `/sys/class/net` has only `lo` and `wlo1`.
There is no built-in NIC and no USB NIC attached.

The QT64 is a **gigabit Ethernet** sensor. It cannot be connected until you add a
**USB 3.0 → gigabit Ethernet adapter** (or a dock with one). USB 2.0 is not enough
headroom — the QT64 streams roughly 10–20 MB/s.

Everything else can be installed and built now; only the final live test needs the adapter.

### 2. Your Wi-Fi LAN collides with the LiDAR's default subnet
```
wlo1   192.168.1.120/24   gateway 192.168.1.254
QT64   192.168.1.201      (factory default, host expected at 192.168.1.100)
```
Both want `192.168.1.0/24`. With two interfaces on one subnet, the kernel can route
LiDAR traffic out the Wi-Fi and you get a driver that connects to nothing.

`setup_lidar_net.sh` works around this by installing a `/32` host route for
`192.168.1.201` pinned to the wired NIC — a /32 beats the Wi-Fi's /24 by
longest-prefix match — and relaxing `rp_filter`.

**The cleaner permanent fix** is to move the LiDAR off 192.168.1.x: browse to
`http://192.168.1.201` (Hesai web UI) while it is the only thing on that subnet,
set the LiDAR to e.g. `192.168.5.201` and its destination host to `192.168.5.100`,
then run:
```bash
sudo LIDAR_IP=192.168.5.201 HOST_IP=192.168.5.100 bash setup_lidar_net.sh
```
and set `device_ip_address: 192.168.5.201` in `config/config.yaml`.

### 3. miniconda is ahead of /usr/bin in your PATH
`python3` and `cmake` currently resolve to `~/miniconda3`. Conda's Python, cmake,
Boost and yaml-cpp will get picked up by colcon and break the build or the
resulting binary. `build_hesai.sh` and `run_hesai.sh` both strip conda from PATH
and unset `PYTHONPATH`/`CONDA_PREFIX` before doing anything — **use those scripts
rather than running `colcon build` in a normal shell**, or activate no conda env.

## Steps

```bash
# 1. Install ROS 2 Jazzy + deps  (needs your password; ~2-4 GB)
sudo bash /home/hao/Work/ros/install_ros2_hesai.sh

# 2. Build the driver  (normal user, no sudo)
bash /home/hao/Work/ros/build_hesai.sh

# 3. Once a USB-Ethernet adapter + the LiDAR are plugged in:
sudo bash /home/hao/Work/ros/setup_lidar_net.sh

# 4. Launch driver + RViz2
bash /home/hao/Work/ros/run_hesai.sh
```

## Config

`hesai_ws/src/HesaiLidar_ROS_2.0/config/config.yaml` — factory defaults already
match a stock QT64, so no edits are needed for a first run:

- `source_type: 1` — live UDP (use `2` to replay a pcap instead)
- `device_ip_address: 192.168.1.201`, `udp_port: 2368`, `ptc_port: 9347`
- `use_ptc_connected: true` — the driver pulls the per-unit angle-correction
  file off the sensor over PTC, so `correction_file_path` can stay as-is.
  If PTC is blocked on your network, set this `false` and point
  `correction_file_path` at the `.csv` from the LiDAR's web UI.

The model is auto-detected over PTC; there is no `lidar_type` to set.

## Checks

```bash
source /opt/ros/jazzy/setup.bash
source /home/hao/Work/ros/hesai_ws/install/setup.bash

ros2 topic hz   /lidar_points     # expect ~10 Hz
ros2 topic echo /lidar_points --field width --once
sudo tcpdump -i <iface> -n udp port 2368 -c 5   # raw packets, driver-independent
```

If `tcpdump` shows packets but RViz is empty, it is almost always the PTC
connection (TCP 9347) failing, so the driver has no correction file.

## No LiDAR yet? Test the whole stack on a pcap

Set `source_type: 2` and point `pcap_type.pcap_path` at a QT64 capture, plus
`correction_file_path` at that unit's correction csv. This verifies ROS, the
driver, and RViz end-to-end without hardware.
