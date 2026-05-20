#!/usr/bin/env bash
set -euo pipefail

#### These steps verify the virtualization host baseline

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/remote.sh"

load_host_config
load_network_config

#### These commands intentionally stay simple and readable

# Show host identity and operating system details.
run_remote hostnamectl

# Show CPU virtualization support and NUMA shape.
run_remote lscpu

# Show current memory and swap state.
run_remote free -h
run_remote swapon --show

# Show block devices before any lab disk is seeded.
run_remote lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL

# Verify libvirt sees the host as capable of running KVM guests.
run_remote virt-host-validate

# Confirm Cockpit and libvirt services are active.
run_remote systemctl is-active cockpit.socket
run_remote systemctl is-active virtqemud.service
run_remote systemctl is-active virtnetworkd.service

# Confirm Open vSwitch and the appliance network service are active.
run_remote systemctl is-active openvswitch.service
run_remote systemctl is-active appliance-install-net.service

# Confirm libvirt command-line access works.
run_remote virsh list --all
run_remote virsh net-list --all

# Confirm the configured OVS bridge exists without a physical uplink.
run_remote ovs-vsctl show
run_remote ip -br addr show "${APPLIANCE_OVS_BRIDGE}"
run_remote ip -br addr show "${APPLIANCE_MACHINE_PORT}"
