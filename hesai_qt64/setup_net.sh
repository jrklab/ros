#!/usr/bin/env bash
# Configure a wired NIC to talk to a Hesai Pandar QT64.
#   sudo bash hesai_qt64/setup_net.sh [IFACE]
#
# Defaults match a factory-fresh QT64:
#   LiDAR  192.168.1.201   UDP/2368 (points)  TCP/9347 (PTC control + calibration)
#   Host   192.168.1.100
#
# Override:  sudo LIDAR_IP=192.168.5.201 HOST_IP=192.168.5.100 bash setup_net.sh
#
# Not persistent - re-run after a reboot or replug.
set -euo pipefail

LIDAR_IP="${LIDAR_IP:-192.168.1.201}"
HOST_IP="${HOST_IP:-192.168.1.100}"
PREFIX="${PREFIX:-24}"

if [[ $EUID -ne 0 ]]; then echo "ERROR: run with sudo: sudo bash $0" >&2; exit 1; fi

# --- Pick the wired interface -------------------------------------------
IFACE="${1:-}"
if [[ -z "$IFACE" ]]; then
  IFACE="$(ls /sys/class/net | grep -E '^(en|eth)' | head -1 || true)"
fi
if [[ -z "$IFACE" ]]; then
  echo "ERROR: no wired interface found. Interfaces present:" >&2
  ls /sys/class/net >&2
  echo "The QT64 is gigabit Ethernet; a USB 3.0 adapter works if the machine has no NIC." >&2
  exit 1
fi
echo "==> Using interface: $IFACE"

# --- Refuse to disturb a live session -----------------------------------
# Flushing the interface deletes the address ROS 2's DDS bound its locators to.
# The driver keeps reading its 0.0.0.0:2368 socket and printing frames, but RViz
# stops receiving and the point cloud appears to freeze.
if pgrep -x hesai_ros_drive >/dev/null || pgrep -x rviz2 >/dev/null; then
  echo "ERROR: the driver and/or RViz are running. Reconfiguring the NIC now" >&2
  echo "       would freeze the point cloud. Stop them first:" >&2
  echo "         pkill -9 -x hesai_ros_drive; pkill -9 -x rviz2" >&2
  echo "       then re-run this script, then run.sh." >&2
  exit 1
fi

# --- Warn about a subnet collision with another interface ----------------
NET="$(echo "$LIDAR_IP" | cut -d. -f1-3)"
CLASH="$(ip -o -4 addr show | grep " $NET\." | grep -v "^.*: $IFACE " || true)"
if [[ -n "$CLASH" ]]; then
  echo "!! WARNING: another interface is already on the ${NET}.0/${PREFIX} subnet:"
  echo "$CLASH" | sed 's/^/     /'
  echo "!! Adding a /32 host route so LiDAR traffic is pinned to $IFACE."
  echo "!! Cleaner long-term fix: move the LiDAR to its own subnet (see README)."
fi

# --- Address ------------------------------------------------------------
ip link set "$IFACE" up
# Only flush if the address is not already what we want - flushing is
# destructive to anything bound to it, so make this a no-op on repeat runs.
if ip -4 addr show dev "$IFACE" | grep -q "inet ${HOST_IP}/${PREFIX}"; then
  echo "==> $IFACE already has ${HOST_IP}/${PREFIX}; leaving it alone"
else
  ip addr flush dev "$IFACE" 2>/dev/null || true
  ip addr add "${HOST_IP}/${PREFIX}" dev "$IFACE"
fi
# A /32 beats any /24 by longest-prefix match, so this wins over a Wi-Fi route
# on the same subnet.
ip route replace "${LIDAR_IP}/32" dev "$IFACE" src "$HOST_IP"

# Loose reverse-path filtering: with two NICs on one subnet, strict rp_filter
# silently drops the LiDAR's UDP.
sysctl -qw "net.ipv4.conf.${IFACE}.rp_filter=2" || true
sysctl -qw net.ipv4.conf.all.rp_filter=2 || true

# --- Receive buffers: a QT64 pushes ~3 MB/s; the default 208 KB can drop ---
sysctl -qw net.core.rmem_max=33554432
sysctl -qw net.core.rmem_default=33554432

# --- Firewall -----------------------------------------------------------
if command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
  echo "==> ufw is active; allowing UDP 2368 + TCP 9347"
  ufw allow in on "$IFACE" to any port 2368 proto udp  >/dev/null || true
  ufw allow in on "$IFACE" to any port 9347 proto tcp  >/dev/null || true
fi

echo
echo "==> Config:"; ip -br addr show "$IFACE"; ip route get "$LIDAR_IP"
echo
echo "==> Pinging LiDAR at $LIDAR_IP ..."
if ping -c 3 -W 2 -I "$IFACE" "$LIDAR_IP"; then
  echo "==> LiDAR reachable."
else
  echo "!! No ping reply. Check cable/adapter, LiDAR power (interface box + 12V),"
  echo "!! and that the LiDAR is at $LIDAR_IP (web UI: http://$LIDAR_IP)."
fi
echo
echo "==> Sniffing 5s for point-cloud packets on UDP 2368 (expect a flood)..."
timeout 5 tcpdump -i "$IFACE" -n udp port 2368 -c 10 2>&1 | tail -15 || true
