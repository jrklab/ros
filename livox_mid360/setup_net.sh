#!/usr/bin/env bash
# Configure a wired NIC to talk to a Livox Mid360 riding on a Unitree G1's
# internal network.
#   sudo bash livox_mid360/setup_net.sh [IFACE]
#
# The G1's internal switch already runs 192.168.123.0/24 (its onboard
# computers are fixed at .161 and .164; the LiDAR was found at .120 by
# process of elimination - TTL 255 and no open TCP ports, unlike the two
# Linux boards). This script only needs to give our own NIC an address on
# that subnet; it must NOT touch the other hosts already there.
#
# Override:  sudo HOST_IP=192.168.123.201 bash setup_net.sh
#
# Not persistent - re-run after a reboot or replug.
set -euo pipefail

HOST_IP="${HOST_IP:-192.168.123.41}"
PREFIX="${PREFIX:-24}"
LIDAR_IP="${LIDAR_IP:-192.168.123.120}"

if [[ $EUID -ne 0 ]]; then echo "ERROR: run with sudo: sudo bash $0" >&2; exit 1; fi

# --- Pick the wired interface -------------------------------------------
IFACE="${1:-}"
if [[ -z "$IFACE" ]]; then
  IFACE="$(ls /sys/class/net | grep -E '^(en|eth)' | head -1 || true)"
fi
if [[ -z "$IFACE" ]]; then
  echo "ERROR: no wired interface found. Interfaces present:" >&2
  ls /sys/class/net >&2
  exit 1
fi
echo "==> Using interface: $IFACE"

# --- Refuse to disturb a live session -----------------------------------
# comm is truncated to 15 chars ('livox_ros_drive'); match -x, not -f, so a
# pattern match against our own shell's command line can't kill our terminal.
if pgrep -x livox_ros_drive >/dev/null || pgrep -x rviz2 >/dev/null; then
  echo "ERROR: the driver and/or RViz are running. Stop them first:" >&2
  echo "         pkill -9 -x livox_ros_drive; pkill -9 -x rviz2" >&2
  echo "       then re-run this script, then run.sh." >&2
  exit 1
fi

# --- Stop NetworkManager from fighting a manually-assigned address -------
# NetworkManager has no DHCP server to talk to on this link. Left "managed",
# it retries DHCP every ~45s, fails, and flushes whatever static address we
# set here - the point cloud looks like it "freezes" for no reason. This
# only affects the local interface entry, not persistent across reboot.
if command -v nmcli >/dev/null && nmcli -t -f DEVICE,STATE device status | grep -q "^${IFACE}:"; then
  echo "==> Marking $IFACE unmanaged by NetworkManager"
  nmcli device set "$IFACE" managed no || true
fi

# --- Address ------------------------------------------------------------
ip link set "$IFACE" up
if ip -4 addr show dev "$IFACE" | grep -q "inet ${HOST_IP}/${PREFIX}"; then
  echo "==> $IFACE already has ${HOST_IP}/${PREFIX}; leaving it alone"
else
  ip addr add "${HOST_IP}/${PREFIX}" dev "$IFACE"
fi

echo
echo "==> Config:"; ip -br addr show "$IFACE"
echo
echo "==> Pinging LiDAR at $LIDAR_IP ..."
if ping -c 3 -W 2 -I "$IFACE" "$LIDAR_IP"; then
  echo "==> LiDAR reachable."
else
  echo "!! No ping reply. Check the G1's power and the Ethernet cable."
fi
