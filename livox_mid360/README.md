# Livox Mid360 (on a Unitree G1) — live point cloud in RViz2

Visualizes the Livox Mid360 mounted on a Unitree G1 humanoid's head, by
plugging a laptop into the G1's Ethernet port and reconfiguring the LiDAR to
stream its data to the laptop instead of the robot's own onboard computer.

**⚠️ Current state: not restored.** As of 2026-09-11 the Mid360's data
destination is still pointed at this laptop's temporary IP
(`192.168.123.41`), not at its original consumer. See
[Restoring the original destination](#restoring-the-original-destination-todo)
— this needs to be done from the onboard computer itself, which this laptop
doesn't have SSH access to.

## Why these pieces

| | |
|---|---|
| **Livox-SDK2** | Livox's C++ SDK. `livox_ros_driver2` links against it (`liblivox_lidar_sdk_shared.so` in `/usr/local`); it is not vendored, `build.sh` clones and installs it. |
| **livox_ros_driver2** | Livox's ROS 2 wrapper. Built with its own `build.sh jazzy`, which swaps in ROS2-specific `package.xml`/`CMakeLists.txt` and runs colcon. |
| **RViz2** | Ships with `ros-jazzy-desktop`. |

## The G1's internal network

The G1 has an internal switch bridging its onboard computers to the external
Ethernet port. Plugging a laptop in and scanning `192.168.123.0/24` found:

| IP | MAC | TTL | Role |
|---|---|---|---|
| `192.168.123.161` | `7e:1d:75:60:f5:89` | 64 (Linux) | Onboard computer generating ~2,200 pkt/s of CycloneDDS/RTPS multicast (`239.255.0.1:7401`) — the perception/control computer. **Original consumer of the Mid360's data.** |
| `192.168.123.164` | `3c:6d:66:f3:22:a3` | 64 (Linux) | Documented in `~/Work/lerobot/docs/source/unitree_g1.mdx` as "the G1's Ethernet IP" — the motion-control computer, reachable at `ssh unitree@192.168.123.164`. |
| `192.168.123.120` | `8c:58:23:a2:d5:8c` | **255** | **The Livox Mid360.** |

How `.120` was identified as the LiDAR (no vendor OUI database match for any
of the three MACs, so this was by protocol fingerprint, not lookup):
- TTL 255 and zero open TCP ports — an embedded/RTOS device, unlike the two
  Linux boards (TTL 64).
- Sent a garbage UDP probe to each Mid360 default port (56000 cmd, 56100
  push-cmd, 56200 point-cloud, 56300 IMU, 56400 log): all five were
  silently absorbed (open|filtered — a real listener drops malformed
  packets rather than erroring). The *legacy* Livox ports (55000, 65000,
  Avia/Horizon-era) came back with explicit ICMP port-unreachable —
  confirmed closed. That combination is a strong Mid360-specific signature.
- Confirmed for certain once the driver ran: its log printed
  `successfully set lidar attitude, ip: 192.168.123.120`.

Passive `tcpdump` did **not** reveal the LiDAR directly — Mid360 streams
point-cloud/IMU data as unicast to whichever host it's configured for, and a
switched network doesn't flood unicast traffic to a third port. Only
broadcast/multicast traffic (the DDS traffic from `.161`) was visible before
reconfiguring anything.

## Setup

```bash
# 1. ROS 2 Jazzy desktop (skip if already installed)
sudo bash ../setup/install_ros2_jazzy.sh

# 2. Driver build dependencies
sudo bash install_deps.sh

# 3. Clone + build Livox-SDK2 (installed to /usr/local) + livox_ros_driver2
bash build.sh

# 4. Configure the NIC — gives this host a static IP on the G1's 192.168.123.0/24
sudo bash setup_net.sh

# 5. Launch driver + RViz2
bash run.sh
```

RViz2 opens preconfigured: `PointCloud2` on `/livox/lidar`, fixed frame
`livox_frame`.

## Defaults

| | |
|---|---|
| LiDAR IP | `192.168.123.120` |
| Host IP (this laptop, temporary) | `192.168.123.41` |
| Original consumer (onboard computer) | `192.168.123.161` |
| Point cloud / IMU / cmd ports | UDP `56300` / `56400` / `56100` (device side; host side is device port **+1**) |
| Topics | `/livox/lidar` (`sensor_msgs/PointCloud2`, `xfer_format: 0`), `/livox/imu` |

Config is tracked at [`config/MID360_config.json`](config/MID360_config.json)
and loaded via the node's `user_config_path` parameter — see
[`launch/mid360.launch.py`](launch/mid360.launch.py).

## How the reconfiguration actually works

`livox_ros_driver2` doesn't just *read* the LiDAR — on startup, whatever
machine runs it pushes `host_net_info` from the JSON config to the LiDAR
over its command channel, telling the LiDAR where to stream point-cloud/IMU
data from then on. The Mid360 only streams to **one** registered host at a
time, so starting the driver here necessarily stole the stream away from
whatever was previously consuming it (`.161`).

**Important gotcha:** the SDK binds a UDP socket to the literal
`host_net_info` IP address. That means **the driver must run on the machine
that actually owns that IP** — you cannot run the driver from host A with
`host_net_info` pointing at host B's address; it fails immediately with
`bind failed`. Reconfiguring the destination back to `.161` therefore
requires running the driver (or an equivalent SDK config push) *from* `.161`
itself, not from this laptop.

## Restoring the original destination (TODO)

This laptop does not have SSH access to `192.168.123.161` (`ssh` to it gets
`Connection refused` on port 22), so the redirect could not be undone from
here. To restore it:

1. Get onto `192.168.123.161` itself (console, or hop through `.164` if it
   can reach `.161` — `.164` is documented as `ssh unitree@192.168.123.164`
   in `~/Work/lerobot/docs/source/unitree_g1.mdx`).
2. Find whatever originally ran there to consume the Mid360 (a
   `livox_ros_driver2` instance is the most likely candidate, given the
   heavy CycloneDDS/RTPS traffic that host was generating). If it's a
   systemd service or auto-started at boot, simply restarting it will
   re-push `host_net_info` = `192.168.123.161` to the LiDAR and reclaim the
   stream — no laptop involvement needed.
3. If there's no such auto-starting service (or it needs a config file),
   use [`config/MID360_config.json`](config/MID360_config.json) as a
   template: change every `192.168.123.41` in `host_net_info` to
   `192.168.123.161`, and run `livox_ros_driver2` (or any Livox-SDK2 tool
   that calls `LivoxLidarSdkInit`) from `.161` with that config.
4. The LiDAR's IP (`192.168.123.120`) and ports don't need to change —
   only `host_net_info`.

## Gotchas

- **NetworkManager fights a manually-assigned static IP.** With no DHCP
  server on this link, NetworkManager retries DHCP every ~45s, fails, and
  flushes the address `setup_net.sh` assigned — the point cloud looks like
  it "freezes" for no reason (same failure mode documented in
  `../hesai_qt64/README.md`). `setup_net.sh` marks the interface unmanaged
  to prevent this; not persistent across reboot.
- **Only one host can receive the Mid360's stream at a time.** Running
  `run.sh` here **will** interrupt whatever else is consuming it on the
  robot's own network — that's exactly what happened to `.161` in this
  session.
- **`bind failed`** when `host_net_info` doesn't match a local address —
  see [How the reconfiguration actually works](#how-the-reconfiguration-actually-works)
  above. This is not a network reachability problem; don't waste time
  debugging routes/firewalls for it.
- **`setup_net.sh` is not persistent.** Re-run after a reboot or replug,
  and update `config/MID360_config.json`'s `host_net_info` IPs to match if
  you pick a different `HOST_IP`.
- **conda breaks the build.** Same reasoning as `../hesai_qt64` — `build.sh`
  and `run.sh` strip conda from `PATH` themselves.
- **CMake ≥ 4 vs. Livox-SDK2's old `cmake_minimum_required`.** `build.sh`
  passes `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` rather than patching
  upstream's `CMakeLists.txt`.

## Stop / restart

```bash
pkill -9 -x livox_ros_drive; pkill -9 -x rviz2
bash run.sh
```

`-x` (exact match on the truncated `comm`, `livox_ros_drive`), not `-f` —
same reasoning as `../hesai_qt64/README.md`.
