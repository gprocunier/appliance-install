#!/usr/bin/env bash
set -euo pipefail

#### These steps install the virtualization host package set

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/remote.sh"

load_host_config

APPLIANCE_OVS_PACKAGE="${APPLIANCE_OVS_PACKAGE:-openvswitch3.6}"

printf -v APPLIANCE_OVS_PACKAGE_REMOTE '%q' "${APPLIANCE_OVS_PACKAGE}"

run_remote_bash <<REMOTE_SCRIPT
set -euo pipefail

APPLIANCE_OVS_PACKAGE=${APPLIANCE_OVS_PACKAGE_REMOTE}

#### These steps install Cockpit, libvirt, KVM, OVS, and support tools

packages=(
    NetworkManager
    "\${APPLIANCE_OVS_PACKAGE}"
    cockpit
    cockpit-files
    cockpit-image-builder
    cockpit-machines
    cockpit-podman
    cockpit-session-recording
    firewalld
    guestfs-tools
    jq
    libvirt
    lvm2
    pcp
    pcp-system-tools
    qemu-kvm
    rsync
    skopeo
    tmux
    virt-install
    virt-top
    xorriso
)

# Install all packages in one transaction so dependency resolution is consistent.
dnf install -y "\${packages[@]}"
REMOTE_SCRIPT
