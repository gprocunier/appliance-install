#!/usr/bin/env bash
set -euo pipefail

#### These steps install the standalone foundry package set

# Run this script from the operator workstation, in the repository root.
# This script installs only the packages needed to mirror and build appliance.raw.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/standalone.sh"

load_standalone_config
validate_standalone_config

run_standalone_root_bash <<'REMOTE_SCRIPT'
set -euo pipefail

#### These steps install container, image, and operator utilities

packages=(
    # Base networking and diagnostic tools.
    NetworkManager
    bind-utils
    curl
    iproute
    jq
    rsync

    # Container and image-copy tooling used by the appliance builder.
    buildah
    podman
    skopeo

    # Image inspection and appliance build support.
    python3
    qemu-img
    tar
    xz

    # Operator utilities for troubleshooting and editing.
    bash-completion
    sos
    tmux
    vim-enhanced
)

# Install all packages in one transaction so dependency resolution is consistent.
dnf install -y "${packages[@]}"

#### These steps prepare the remote appliance workspace

# The standalone path does not configure DNS, NTP, OVS, libvirt, or Cockpit.
echo "Standalone foundry package installation is complete."
REMOTE_SCRIPT
