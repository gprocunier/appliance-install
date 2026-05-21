#!/usr/bin/env bash
set -euo pipefail

#### These steps install the virtualization host package set

# Run this script from the operator workstation, in the repository root.
# This script installs packages on the virtualization host over SSH.

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
    # Base host networking and firewall services.
    NetworkManager
    firewalld
    "\${APPLIANCE_OVS_PACKAGE}"

    # Cockpit core and useful management pages.
    cockpit
    cockpit-files
    cockpit-image-builder
    cockpit-machines
    cockpit-packagekit
    cockpit-podman
    cockpit-session-recording
    cockpit-storaged
    cockpit-system
    cockpit-ws-selinux

    # Virtualization host services and VM console/viewer tools.
    libvirt
    qemu-kvm
    virt-install
    virt-manager
    virt-top
    virt-viewer
    virtio-win

    # Container and image-copy tooling used by foundry and demos.
    buildah
    podman
    skopeo

    # Guest image inspection, customization, and rescue tooling.
    guestfs-tools
    libguestfs-rescue

    # Operator utilities for troubleshooting and editing.
    bash-completion
    bind-utils
    jq
    lvm2
    nmap-ncat
    pcp
    pcp-system-tools
    policycoreutils-python-utils
    rsync
    sos
    setroubleshoot-server
    tcpdump
    tmux
    vim-enhanced
    xorriso
)

# Install all packages in one transaction so dependency resolution is consistent.
dnf install -y "\${packages[@]}"

# Reboot before service setup so virtualization and OVS services start cleanly.
sleep 5
echo "Rebooting virtualization host"
reboot
REMOTE_SCRIPT
