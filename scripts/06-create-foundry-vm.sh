#!/usr/bin/env bash
set -euo pipefail

#### These steps build the foundry virtual machine

# Run this script from the operator workstation, in the repository root.
# This script creates a dual-homed foundry VM on the virtualization host.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/remote.sh"

load_host_config
load_network_config
load_foundry_config

APPLIANCE_FOUNDRY_SHORT_HOSTNAME="${APPLIANCE_FOUNDRY_SHORT_HOSTNAME:-foundry}"
APPLIANCE_FOUNDRY_HOSTNAME="${APPLIANCE_FOUNDRY_HOSTNAME:-foundry.appliance.workshop.lan}"
APPLIANCE_FOUNDRY_MEMORY_MB="${APPLIANCE_FOUNDRY_MEMORY_MB:-32768}"
APPLIANCE_FOUNDRY_VCPUS="${APPLIANCE_FOUNDRY_VCPUS:-8}"
APPLIANCE_FOUNDRY_DISK_SIZE_GB="${APPLIANCE_FOUNDRY_DISK_SIZE_GB:-300}"
APPLIANCE_FOUNDRY_OS_VARIANT="${APPLIANCE_FOUNDRY_OS_VARIANT:-rhel10.1}"
APPLIANCE_FOUNDRY_IMAGE_DIR="${APPLIANCE_FOUNDRY_IMAGE_DIR:-/var/lib/libvirt/images}"
APPLIANCE_FOUNDRY_BASE_IMAGE="${APPLIANCE_FOUNDRY_BASE_IMAGE:-}"
APPLIANCE_FOUNDRY_UPSTREAM_NETWORK="${APPLIANCE_FOUNDRY_UPSTREAM_NETWORK:-default}"
APPLIANCE_FOUNDRY_UPSTREAM_MAC="${APPLIANCE_FOUNDRY_UPSTREAM_MAC:-52:54:00:10:10:10}"
APPLIANCE_FOUNDRY_APPLIANCE_MAC="${APPLIANCE_FOUNDRY_APPLIANCE_MAC:-52:54:00:10:10:11}"
APPLIANCE_FOUNDRY_APPLIANCE_PREFIX="${APPLIANCE_FOUNDRY_APPLIANCE_PREFIX:-24}"
APPLIANCE_FOUNDRY_SSH_PUBLIC_KEY_FILE="${APPLIANCE_FOUNDRY_SSH_PUBLIC_KEY_FILE:-${APPLIANCE_FOUNDRY_SSH_KEY}.pub}"
APPLIANCE_FOUNDRY_WAIT_FOR_SSH="${APPLIANCE_FOUNDRY_WAIT_FOR_SSH:-true}"

if [[ -z "${APPLIANCE_FOUNDRY_BASE_IMAGE}" ]]; then
    echo "APPLIANCE_FOUNDRY_BASE_IMAGE must be set in config/foundry.env." >&2
    exit 1
fi

if [[ ! -f "${APPLIANCE_FOUNDRY_SSH_PUBLIC_KEY_FILE}" ]]; then
    echo "Missing SSH public key: ${APPLIANCE_FOUNDRY_SSH_PUBLIC_KEY_FILE}" >&2
    echo "Set APPLIANCE_FOUNDRY_SSH_PUBLIC_KEY_FILE in config/foundry.env." >&2
    exit 1
fi

APPLIANCE_FOUNDRY_SSH_PUBLIC_KEY="$(<"${APPLIANCE_FOUNDRY_SSH_PUBLIC_KEY_FILE}")"

printf -v FOUNDRY_NAME_REMOTE '%q' "${APPLIANCE_FOUNDRY_NAME}"
printf -v FOUNDRY_SHORT_HOSTNAME_REMOTE '%q' "${APPLIANCE_FOUNDRY_SHORT_HOSTNAME}"
printf -v FOUNDRY_HOSTNAME_REMOTE '%q' "${APPLIANCE_FOUNDRY_HOSTNAME}"
printf -v FOUNDRY_USER_REMOTE '%q' "${APPLIANCE_FOUNDRY_USER}"
printf -v FOUNDRY_MEMORY_REMOTE '%q' "${APPLIANCE_FOUNDRY_MEMORY_MB}"
printf -v FOUNDRY_VCPUS_REMOTE '%q' "${APPLIANCE_FOUNDRY_VCPUS}"
printf -v FOUNDRY_DISK_SIZE_REMOTE '%q' "${APPLIANCE_FOUNDRY_DISK_SIZE_GB}"
printf -v FOUNDRY_OS_VARIANT_REMOTE '%q' "${APPLIANCE_FOUNDRY_OS_VARIANT}"
printf -v FOUNDRY_IMAGE_DIR_REMOTE '%q' "${APPLIANCE_FOUNDRY_IMAGE_DIR}"
printf -v FOUNDRY_BASE_IMAGE_REMOTE '%q' "${APPLIANCE_FOUNDRY_BASE_IMAGE}"
printf -v FOUNDRY_UPSTREAM_NETWORK_REMOTE '%q' "${APPLIANCE_FOUNDRY_UPSTREAM_NETWORK}"
printf -v FOUNDRY_UPSTREAM_MAC_REMOTE '%q' "${APPLIANCE_FOUNDRY_UPSTREAM_MAC}"
printf -v FOUNDRY_APPLIANCE_NETWORK_REMOTE '%q' "${APPLIANCE_LIBVIRT_NETWORK}"
printf -v FOUNDRY_APPLIANCE_PORTGROUP_REMOTE '%q' "${APPLIANCE_MACHINE_PORTGROUP}"
printf -v FOUNDRY_APPLIANCE_MAC_REMOTE '%q' "${APPLIANCE_FOUNDRY_APPLIANCE_MAC}"
printf -v FOUNDRY_APPLIANCE_IP_REMOTE '%q' "${APPLIANCE_FOUNDRY_APPLIANCE_IP}"
printf -v FOUNDRY_APPLIANCE_PREFIX_REMOTE '%q' "${APPLIANCE_FOUNDRY_APPLIANCE_PREFIX}"
printf -v FOUNDRY_SSH_PUBLIC_KEY_REMOTE '%q' "${APPLIANCE_FOUNDRY_SSH_PUBLIC_KEY}"
printf -v FOUNDRY_WAIT_FOR_SSH_REMOTE '%q' "${APPLIANCE_FOUNDRY_WAIT_FOR_SSH}"

run_remote_bash <<REMOTE_SCRIPT
set -euo pipefail

FOUNDRY_NAME=${FOUNDRY_NAME_REMOTE}
FOUNDRY_SHORT_HOSTNAME=${FOUNDRY_SHORT_HOSTNAME_REMOTE}
FOUNDRY_HOSTNAME=${FOUNDRY_HOSTNAME_REMOTE}
FOUNDRY_USER=${FOUNDRY_USER_REMOTE}
FOUNDRY_MEMORY_MB=${FOUNDRY_MEMORY_REMOTE}
FOUNDRY_VCPUS=${FOUNDRY_VCPUS_REMOTE}
FOUNDRY_DISK_SIZE_GB=${FOUNDRY_DISK_SIZE_REMOTE}
FOUNDRY_OS_VARIANT=${FOUNDRY_OS_VARIANT_REMOTE}
FOUNDRY_IMAGE_DIR=${FOUNDRY_IMAGE_DIR_REMOTE}
FOUNDRY_BASE_IMAGE=${FOUNDRY_BASE_IMAGE_REMOTE}
FOUNDRY_UPSTREAM_NETWORK=${FOUNDRY_UPSTREAM_NETWORK_REMOTE}
FOUNDRY_UPSTREAM_MAC=${FOUNDRY_UPSTREAM_MAC_REMOTE}
FOUNDRY_APPLIANCE_NETWORK=${FOUNDRY_APPLIANCE_NETWORK_REMOTE}
FOUNDRY_APPLIANCE_PORTGROUP=${FOUNDRY_APPLIANCE_PORTGROUP_REMOTE}
FOUNDRY_APPLIANCE_MAC=${FOUNDRY_APPLIANCE_MAC_REMOTE}
FOUNDRY_APPLIANCE_IP=${FOUNDRY_APPLIANCE_IP_REMOTE}
FOUNDRY_APPLIANCE_PREFIX=${FOUNDRY_APPLIANCE_PREFIX_REMOTE}
FOUNDRY_SSH_PUBLIC_KEY=${FOUNDRY_SSH_PUBLIC_KEY_REMOTE}
FOUNDRY_WAIT_FOR_SSH=${FOUNDRY_WAIT_FOR_SSH_REMOTE}

FOUNDRY_DISK="\${FOUNDRY_IMAGE_DIR}/\${FOUNDRY_NAME}.qcow2"
FOUNDRY_SEED_DIR="\${FOUNDRY_IMAGE_DIR}/\${FOUNDRY_NAME}-seed"
FOUNDRY_SEED_ISO="\${FOUNDRY_IMAGE_DIR}/\${FOUNDRY_NAME}-seed.iso"

#### These steps validate host prerequisites before creating the VM

# The upstream network gives foundry a path for downloads and mirroring.
if ! virsh net-info "\${FOUNDRY_UPSTREAM_NETWORK}" >/dev/null 2>&1; then
    echo "Missing libvirt upstream network: \${FOUNDRY_UPSTREAM_NETWORK}" >&2
    exit 1
fi

# The appliance network is the OVS-only lab network created by script 04.
if ! virsh net-info "\${FOUNDRY_APPLIANCE_NETWORK}" >/dev/null 2>&1; then
    echo "Missing libvirt appliance network: \${FOUNDRY_APPLIANCE_NETWORK}" >&2
    exit 1
fi

# The base image is intentionally operator-provided and not committed.
if [[ ! -f "\${FOUNDRY_BASE_IMAGE}" ]]; then
    echo "Missing foundry base image on virtualization host: \${FOUNDRY_BASE_IMAGE}" >&2
    exit 1
fi

# Do not overwrite an existing domain; remove it intentionally before rerunning.
if virsh dominfo "\${FOUNDRY_NAME}" >/dev/null 2>&1; then
    echo "Foundry VM \${FOUNDRY_NAME} already exists."
    exit 0
fi

# Do not overwrite an existing disk; move it intentionally before rerunning.
if [[ -f "\${FOUNDRY_DISK}" ]]; then
    echo "Foundry disk already exists: \${FOUNDRY_DISK}" >&2
    exit 1
fi

#### These steps create the foundry VM disk and cloud-init seed

# Copy the cloud image into an independent foundry disk.
mkdir -p "\${FOUNDRY_IMAGE_DIR}"
qemu-img convert -O qcow2 "\${FOUNDRY_BASE_IMAGE}" "\${FOUNDRY_DISK}"
qemu-img resize "\${FOUNDRY_DISK}" "\${FOUNDRY_DISK_SIZE_GB}G"

# Recreate the generated seed content for this VM.
rm -rf "\${FOUNDRY_SEED_DIR}"
mkdir -p "\${FOUNDRY_SEED_DIR}"

cat > "\${FOUNDRY_SEED_DIR}/meta-data" <<META_DATA
instance-id: \${FOUNDRY_NAME}
local-hostname: \${FOUNDRY_SHORT_HOSTNAME}
META_DATA

cat > "\${FOUNDRY_SEED_DIR}/user-data" <<USER_DATA
#cloud-config
hostname: \${FOUNDRY_SHORT_HOSTNAME}
fqdn: \${FOUNDRY_HOSTNAME}
manage_etc_hosts: true
ssh_pwauth: false
users:
  - default
  - name: \${FOUNDRY_USER}
    groups: wheel
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - "\${FOUNDRY_SSH_PUBLIC_KEY}"
disable_root: true
growpart:
  mode: auto
  devices:
    - /
resize_rootfs: true
USER_DATA

cat > "\${FOUNDRY_SEED_DIR}/network-config" <<NETWORK_CONFIG
version: 2
ethernets:
  upstream:
    match:
      macaddress: "\${FOUNDRY_UPSTREAM_MAC}"
    set-name: enp1s0
    dhcp4: true
  appliance:
    match:
      macaddress: "\${FOUNDRY_APPLIANCE_MAC}"
    set-name: enp2s0
    dhcp4: false
    addresses:
      - "\${FOUNDRY_APPLIANCE_IP}/\${FOUNDRY_APPLIANCE_PREFIX}"
NETWORK_CONFIG

# Build the NoCloud seed ISO used by cloud-init.
rm -f "\${FOUNDRY_SEED_ISO}"
mkisofs \
    -output "\${FOUNDRY_SEED_ISO}" \
    -volid cidata \
    -joliet \
    -rock \
    "\${FOUNDRY_SEED_DIR}/user-data" \
    "\${FOUNDRY_SEED_DIR}/meta-data" \
    "\${FOUNDRY_SEED_DIR}/network-config"

#### These steps define and start the foundry VM

# Attach foundry to both the upstream network and the OVS appliance network.
virt-install \
    --name "\${FOUNDRY_NAME}" \
    --memory "\${FOUNDRY_MEMORY_MB}" \
    --vcpus "\${FOUNDRY_VCPUS}" \
    --os-variant "\${FOUNDRY_OS_VARIANT}" \
    --import \
    --disk "path=\${FOUNDRY_DISK},format=qcow2,bus=virtio" \
    --disk "path=\${FOUNDRY_SEED_ISO},device=cdrom" \
    --network "network=\${FOUNDRY_UPSTREAM_NETWORK},model=virtio,mac=\${FOUNDRY_UPSTREAM_MAC}" \
    --network "network=\${FOUNDRY_APPLIANCE_NETWORK},portgroup=\${FOUNDRY_APPLIANCE_PORTGROUP},model=virtio,mac=\${FOUNDRY_APPLIANCE_MAC}" \
    --graphics none \
    --console pty,target_type=serial \
    --noautoconsole

#### These steps wait for foundry SSH on the appliance network

if [[ "\${FOUNDRY_WAIT_FOR_SSH}" == "true" ]]; then
    for attempt in {1..60}; do
        if timeout 2 bash -c "</dev/tcp/\${FOUNDRY_APPLIANCE_IP}/22" >/dev/null 2>&1; then
            echo "Foundry SSH is reachable at \${FOUNDRY_APPLIANCE_IP}."
            exit 0
        fi

        echo "Waiting for foundry SSH at \${FOUNDRY_APPLIANCE_IP}... attempt \${attempt}/60"
        sleep 10
    done

    echo "Foundry VM was created, but SSH did not become reachable before timeout." >&2
    exit 1
fi
REMOTE_SCRIPT
