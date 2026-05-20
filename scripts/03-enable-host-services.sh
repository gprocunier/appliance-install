#!/usr/bin/env bash
set -euo pipefail

#### These steps enable the services needed for Cockpit and virtual machines

# Run this script from the operator workstation, in the repository root.
# This script enables services on the virtualization host over SSH.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/remote.sh"

load_host_config

run_remote_bash <<'REMOTE_SCRIPT'
set -euo pipefail

#### These steps enable base host services

# NetworkManager and firewalld should be active before libvirt networks are used.
systemctl enable --now NetworkManager.service
systemctl enable --now firewalld.service

# Cockpit listens on port 9090 through a socket-activated service.
systemctl enable --now cockpit.socket

#### These steps enable virtualization services

# Open vSwitch is required for the Calabi lab bridge model.
systemctl enable --now openvswitch.service

# RHEL 10 uses modular libvirt daemons for QEMU and virtual networking.
systemctl enable --now virtqemud.service
systemctl enable --now virtnetworkd.service
systemctl enable --now virtnodedevd.service
systemctl enable --now virtstoraged.service

# Socket activation keeps libvirt responsive after reboot.
systemctl enable --now virtqemud.socket
systemctl enable --now virtnetworkd.socket
systemctl enable --now virtnodedevd.socket
systemctl enable --now virtstoraged.socket

#### These steps allow operator access to Cockpit

# Keep SSH and Cockpit reachable through the host firewall.
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-service=cockpit
firewall-cmd --reload
REMOTE_SCRIPT
