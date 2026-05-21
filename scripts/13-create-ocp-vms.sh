#!/usr/bin/env bash
set -euo pipefail

#### These steps create the three OpenShift appliance VMs

# Run this script from the operator workstation, in the repository root.
# It copies the appliance image from foundry and defines ocp-01, ocp-02, ocp-03.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/remote.sh"

load_host_config
load_network_config
load_foundry_config
load_appliance_config

APPLIANCE_ASSETS_DIR="${APPLIANCE_ASSETS_DIR:-/srv/appliance/assets}"
APPLIANCE_CLUSTER_CONFIG_DIR="${APPLIANCE_CLUSTER_CONFIG_DIR:-/srv/appliance/cluster-config}"
APPLIANCE_OCP_IMAGE_DIR="${APPLIANCE_OCP_IMAGE_DIR:-/home/libvirt/images/appliance-install}"
APPLIANCE_OCP_OS_VARIANT="${APPLIANCE_OCP_OS_VARIANT:-fedora-coreos-stable}"
APPLIANCE_REFRESH_BASE_IMAGE="${APPLIANCE_REFRESH_BASE_IMAGE:-false}"
APPLIANCE_PRUNE_FOUNDRY_BUILD_CACHE_BEFORE_COPY="${APPLIANCE_PRUNE_FOUNDRY_BUILD_CACHE_BEFORE_COPY:-true}"
APPLIANCE_KEEP_HOST_RAW_IMAGE="${APPLIANCE_KEEP_HOST_RAW_IMAGE:-false}"
APPLIANCE_NODE_1_MAC="${APPLIANCE_NODE_1_MAC:-52:54:00:10:11:11}"
APPLIANCE_NODE_2_MAC="${APPLIANCE_NODE_2_MAC:-52:54:00:10:11:12}"
APPLIANCE_NODE_3_MAC="${APPLIANCE_NODE_3_MAC:-52:54:00:10:11:13}"
APPLIANCE_NODE_1_VCPUS="${APPLIANCE_NODE_1_VCPUS:-12}"
APPLIANCE_NODE_2_VCPUS="${APPLIANCE_NODE_2_VCPUS:-12}"
APPLIANCE_NODE_3_VCPUS="${APPLIANCE_NODE_3_VCPUS:-12}"
APPLIANCE_NODE_1_MEMORY_MB="${APPLIANCE_NODE_1_MEMORY_MB:-32768}"
APPLIANCE_NODE_2_MEMORY_MB="${APPLIANCE_NODE_2_MEMORY_MB:-32768}"
APPLIANCE_NODE_3_MEMORY_MB="${APPLIANCE_NODE_3_MEMORY_MB:-32768}"
APPLIANCE_NODE_1_DISK_SIZE_GB="${APPLIANCE_NODE_1_DISK_SIZE_GB:-200}"
APPLIANCE_NODE_2_DISK_SIZE_GB="${APPLIANCE_NODE_2_DISK_SIZE_GB:-200}"
APPLIANCE_NODE_3_DISK_SIZE_GB="${APPLIANCE_NODE_3_DISK_SIZE_GB:-200}"

#### These steps validate VM settings before copying large artifacts

validate_absolute_path "APPLIANCE_ASSETS_DIR" "${APPLIANCE_ASSETS_DIR}"
validate_absolute_path "APPLIANCE_CLUSTER_CONFIG_DIR" "${APPLIANCE_CLUSTER_CONFIG_DIR}"
validate_absolute_path "APPLIANCE_OCP_IMAGE_DIR" "${APPLIANCE_OCP_IMAGE_DIR}"
validate_simple_name "APPLIANCE_OCP_OS_VARIANT" "${APPLIANCE_OCP_OS_VARIANT}"
validate_boolean "APPLIANCE_REFRESH_BASE_IMAGE" "${APPLIANCE_REFRESH_BASE_IMAGE}"
validate_boolean "APPLIANCE_PRUNE_FOUNDRY_BUILD_CACHE_BEFORE_COPY" "${APPLIANCE_PRUNE_FOUNDRY_BUILD_CACHE_BEFORE_COPY}"
validate_boolean "APPLIANCE_KEEP_HOST_RAW_IMAGE" "${APPLIANCE_KEEP_HOST_RAW_IMAGE}"
validate_ipv4 "APPLIANCE_FOUNDRY_APPLIANCE_IP" "${APPLIANCE_FOUNDRY_APPLIANCE_IP}"
validate_linux_user "APPLIANCE_FOUNDRY_USER" "${APPLIANCE_FOUNDRY_USER}"
validate_simple_name "APPLIANCE_LIBVIRT_NETWORK" "${APPLIANCE_LIBVIRT_NETWORK}"
validate_simple_name "APPLIANCE_MACHINE_PORTGROUP" "${APPLIANCE_MACHINE_PORTGROUP}"
validate_dns_label "APPLIANCE_NODE_1_NAME" "${APPLIANCE_NODE_1_NAME}"
validate_dns_label "APPLIANCE_NODE_2_NAME" "${APPLIANCE_NODE_2_NAME}"
validate_dns_label "APPLIANCE_NODE_3_NAME" "${APPLIANCE_NODE_3_NAME}"
validate_mac "APPLIANCE_NODE_1_MAC" "${APPLIANCE_NODE_1_MAC}"
validate_mac "APPLIANCE_NODE_2_MAC" "${APPLIANCE_NODE_2_MAC}"
validate_mac "APPLIANCE_NODE_3_MAC" "${APPLIANCE_NODE_3_MAC}"
validate_positive_integer "APPLIANCE_NODE_1_VCPUS" "${APPLIANCE_NODE_1_VCPUS}"
validate_positive_integer "APPLIANCE_NODE_2_VCPUS" "${APPLIANCE_NODE_2_VCPUS}"
validate_positive_integer "APPLIANCE_NODE_3_VCPUS" "${APPLIANCE_NODE_3_VCPUS}"
validate_positive_integer "APPLIANCE_NODE_1_MEMORY_MB" "${APPLIANCE_NODE_1_MEMORY_MB}"
validate_positive_integer "APPLIANCE_NODE_2_MEMORY_MB" "${APPLIANCE_NODE_2_MEMORY_MB}"
validate_positive_integer "APPLIANCE_NODE_3_MEMORY_MB" "${APPLIANCE_NODE_3_MEMORY_MB}"
validate_positive_integer "APPLIANCE_NODE_1_DISK_SIZE_GB" "${APPLIANCE_NODE_1_DISK_SIZE_GB}"
validate_positive_integer "APPLIANCE_NODE_2_DISK_SIZE_GB" "${APPLIANCE_NODE_2_DISK_SIZE_GB}"
validate_positive_integer "APPLIANCE_NODE_3_DISK_SIZE_GB" "${APPLIANCE_NODE_3_DISK_SIZE_GB}"

#### These steps copy appliance artifacts from foundry to the virt host

# Tar sparse mode keeps holes in appliance.raw from expanding over the wire.
echo "Copying appliance.raw and agentconfig.noarch.iso from foundry to the virtualization host."
echo "Destination on virtualization host: ${APPLIANCE_OCP_IMAGE_DIR}"
TRANSFER_KEY_DIR=""
TRANSFER_KEY_PATH=""
TRANSFER_PUBLIC_KEY=""

cleanup_transfer_access() {
    local transfer_public_key_remote
    local foundry_user_remote
    local transfer_key_dir_remote

    if [[ -n "${TRANSFER_PUBLIC_KEY}" ]]; then
        printf -v transfer_public_key_remote '%q' "${TRANSFER_PUBLIC_KEY}"
        printf -v foundry_user_remote '%q' "${APPLIANCE_FOUNDRY_USER}"
        run_foundry sudo -n /bin/bash -s <<REMOTE_SCRIPT || true
set -euo pipefail

FOUNDRY_USER=${foundry_user_remote}
TRANSFER_PUBLIC_KEY=${transfer_public_key_remote}
FOUNDRY_HOME="\$(getent passwd "\${FOUNDRY_USER}" | cut -d: -f6)"
AUTHORIZED_KEYS="\${FOUNDRY_HOME}/.ssh/authorized_keys"

if [[ -f "\${AUTHORIZED_KEYS}" ]]; then
    sed -i "\\#\${TRANSFER_PUBLIC_KEY}#d" "\${AUTHORIZED_KEYS}"
fi
REMOTE_SCRIPT
    fi

    if [[ -n "${TRANSFER_KEY_DIR}" ]]; then
        printf -v transfer_key_dir_remote '%q' "${TRANSFER_KEY_DIR}"
        run_remote rm -rf "${transfer_key_dir_remote}" || true
    fi
}

trap cleanup_transfer_access EXIT

printf -v ASSETS_DIR_REMOTE '%q' "${APPLIANCE_ASSETS_DIR}"
printf -v CLUSTER_CONFIG_DIR_REMOTE '%q' "${APPLIANCE_CLUSTER_CONFIG_DIR}"
printf -v OCP_IMAGE_DIR_REMOTE '%q' "${APPLIANCE_OCP_IMAGE_DIR}"
printf -v KEEP_HOST_RAW_IMAGE_REMOTE '%q' "${APPLIANCE_KEEP_HOST_RAW_IMAGE}"

if run_remote test -f "${APPLIANCE_OCP_IMAGE_DIR}/appliance-base.qcow2" && [[ "${APPLIANCE_REFRESH_BASE_IMAGE}" == "false" ]]; then
    COPY_BASE_IMAGE="false"
    echo "Reusing existing appliance-base.qcow2 on the virtualization host."
else
    COPY_BASE_IMAGE="true"
    echo "Refreshing appliance-base.qcow2 from foundry appliance.raw."
fi

if [[ "${COPY_BASE_IMAGE}" == "true" && "${APPLIANCE_PRUNE_FOUNDRY_BUILD_CACHE_BEFORE_COPY}" == "true" ]]; then
    run_foundry sudo -n /bin/bash -s <<REMOTE_SCRIPT
set -euo pipefail

ASSETS_DIR=${ASSETS_DIR_REMOTE}

#### These steps reclaim foundry build cache space before the large copy

# appliance.raw must exist before temporary mirror/build cache is removed.
if [[ ! -f "\${ASSETS_DIR}/appliance.raw" ]]; then
    echo "Missing \${ASSETS_DIR}/appliance.raw. Run script 11 first." >&2
    exit 1
fi

echo "Pruning foundry appliance build cache under \${ASSETS_DIR}."
rm -rf "\${ASSETS_DIR}/temp" "\${ASSETS_DIR}/cache"
sync
fstrim -v / || true
REMOTE_SCRIPT
fi

#### These steps create temporary direct access from virt host to foundry

# Direct host-to-foundry transfer avoids routing the large image through this workstation.
TRANSFER_KEY_DIR="$(run_remote mktemp -d /tmp/appliance-install-transfer.XXXXXX)"
TRANSFER_KEY_PATH="${TRANSFER_KEY_DIR}/id_ed25519"
printf -v TRANSFER_KEY_DIR_REMOTE '%q' "${TRANSFER_KEY_DIR}"
printf -v TRANSFER_KEY_PATH_REMOTE '%q' "${TRANSFER_KEY_PATH}"

TRANSFER_PUBLIC_KEY="$(run_remote_bash <<REMOTE_SCRIPT
set -euo pipefail

TRANSFER_KEY_DIR=${TRANSFER_KEY_DIR_REMOTE}
TRANSFER_KEY_PATH=${TRANSFER_KEY_PATH_REMOTE}

install -d -m 0700 "\${TRANSFER_KEY_DIR}"
ssh-keygen -t ed25519 -N '' -C appliance-install-transfer -f "\${TRANSFER_KEY_PATH}" >/dev/null
cat "\${TRANSFER_KEY_PATH}.pub"
REMOTE_SCRIPT
)"

validate_ssh_public_key "TRANSFER_PUBLIC_KEY" "${TRANSFER_PUBLIC_KEY}"

printf -v TRANSFER_PUBLIC_KEY_REMOTE '%q' "${TRANSFER_PUBLIC_KEY}"
printf -v FOUNDRY_USER_REMOTE '%q' "${APPLIANCE_FOUNDRY_USER}"
printf -v COPY_BASE_IMAGE_REMOTE '%q' "${COPY_BASE_IMAGE}"

run_foundry sudo -n /bin/bash -s <<REMOTE_SCRIPT
set -euo pipefail

FOUNDRY_USER=${FOUNDRY_USER_REMOTE}
TRANSFER_PUBLIC_KEY=${TRANSFER_PUBLIC_KEY_REMOTE}
FOUNDRY_HOME="\$(getent passwd "\${FOUNDRY_USER}" | cut -d: -f6)"
AUTHORIZED_KEYS="\${FOUNDRY_HOME}/.ssh/authorized_keys"

install -d -m 0700 -o "\${FOUNDRY_USER}" -g "\${FOUNDRY_USER}" "\${FOUNDRY_HOME}/.ssh"
touch "\${AUTHORIZED_KEYS}"
grep -qxF "\${TRANSFER_PUBLIC_KEY}" "\${AUTHORIZED_KEYS}" || echo "\${TRANSFER_PUBLIC_KEY}" >> "\${AUTHORIZED_KEYS}"
chown "\${FOUNDRY_USER}:\${FOUNDRY_USER}" "\${AUTHORIZED_KEYS}"
chmod 0600 "\${AUTHORIZED_KEYS}"
REMOTE_SCRIPT

printf -v FOUNDRY_IP_REMOTE '%q' "${APPLIANCE_FOUNDRY_APPLIANCE_IP}"

run_remote_bash <<REMOTE_SCRIPT
set -euo pipefail

ASSETS_DIR=${ASSETS_DIR_REMOTE}
CLUSTER_CONFIG_DIR=${CLUSTER_CONFIG_DIR_REMOTE}
OCP_IMAGE_DIR=${OCP_IMAGE_DIR_REMOTE}
TRANSFER_KEY_PATH=${TRANSFER_KEY_PATH_REMOTE}
FOUNDRY_USER=${FOUNDRY_USER_REMOTE}
FOUNDRY_IP=${FOUNDRY_IP_REMOTE}
COPY_BASE_IMAGE=${COPY_BASE_IMAGE_REMOTE}

mkdir -p "\${OCP_IMAGE_DIR}"
rm -f "\${OCP_IMAGE_DIR}/agentconfig.noarch.iso"

if [[ "\${COPY_BASE_IMAGE}" == "true" ]]; then
    rm -f "\${OCP_IMAGE_DIR}/appliance.raw"
fi

echo "Pulling sparse appliance artifacts directly from \${FOUNDRY_IP} to this virtualization host."
if [[ "\${COPY_BASE_IMAGE}" == "true" ]]; then
    ssh \
        -i "\${TRANSFER_KEY_PATH}" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=10 \
        "\${FOUNDRY_USER}@\${FOUNDRY_IP}" \
        "sudo -n tar --sparse -C \${ASSETS_DIR} -cf - appliance.raw -C \${CLUSTER_CONFIG_DIR} agentconfig.noarch.iso" | \
        tar --sparse -C "\${OCP_IMAGE_DIR}" -xf -
    ls -lh "\${OCP_IMAGE_DIR}/appliance.raw" "\${OCP_IMAGE_DIR}/agentconfig.noarch.iso"
else
    ssh \
        -i "\${TRANSFER_KEY_PATH}" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=10 \
        "\${FOUNDRY_USER}@\${FOUNDRY_IP}" \
        "sudo -n tar -C \${CLUSTER_CONFIG_DIR} -cf - agentconfig.noarch.iso" | \
        tar -C "\${OCP_IMAGE_DIR}" -xf -
    ls -lh "\${OCP_IMAGE_DIR}/agentconfig.noarch.iso"
fi
REMOTE_SCRIPT

printf -v OCP_OS_VARIANT_REMOTE '%q' "${APPLIANCE_OCP_OS_VARIANT}"
printf -v LIBVIRT_NETWORK_REMOTE '%q' "${APPLIANCE_LIBVIRT_NETWORK}"
printf -v MACHINE_PORTGROUP_REMOTE '%q' "${APPLIANCE_MACHINE_PORTGROUP}"
printf -v COPY_BASE_IMAGE_REMOTE '%q' "${COPY_BASE_IMAGE}"
printf -v NODE_1_NAME_REMOTE '%q' "${APPLIANCE_NODE_1_NAME}"
printf -v NODE_1_MAC_REMOTE '%q' "${APPLIANCE_NODE_1_MAC}"
printf -v NODE_1_VCPUS_REMOTE '%q' "${APPLIANCE_NODE_1_VCPUS}"
printf -v NODE_1_MEMORY_REMOTE '%q' "${APPLIANCE_NODE_1_MEMORY_MB}"
printf -v NODE_1_DISK_REMOTE '%q' "${APPLIANCE_NODE_1_DISK_SIZE_GB}"
printf -v NODE_2_NAME_REMOTE '%q' "${APPLIANCE_NODE_2_NAME}"
printf -v NODE_2_MAC_REMOTE '%q' "${APPLIANCE_NODE_2_MAC}"
printf -v NODE_2_VCPUS_REMOTE '%q' "${APPLIANCE_NODE_2_VCPUS}"
printf -v NODE_2_MEMORY_REMOTE '%q' "${APPLIANCE_NODE_2_MEMORY_MB}"
printf -v NODE_2_DISK_REMOTE '%q' "${APPLIANCE_NODE_2_DISK_SIZE_GB}"
printf -v NODE_3_NAME_REMOTE '%q' "${APPLIANCE_NODE_3_NAME}"
printf -v NODE_3_MAC_REMOTE '%q' "${APPLIANCE_NODE_3_MAC}"
printf -v NODE_3_VCPUS_REMOTE '%q' "${APPLIANCE_NODE_3_VCPUS}"
printf -v NODE_3_MEMORY_REMOTE '%q' "${APPLIANCE_NODE_3_MEMORY_MB}"
printf -v NODE_3_DISK_REMOTE '%q' "${APPLIANCE_NODE_3_DISK_SIZE_GB}"

run_remote_bash <<REMOTE_SCRIPT
set -euo pipefail

OCP_IMAGE_DIR=${OCP_IMAGE_DIR_REMOTE}
OCP_OS_VARIANT=${OCP_OS_VARIANT_REMOTE}
LIBVIRT_NETWORK=${LIBVIRT_NETWORK_REMOTE}
MACHINE_PORTGROUP=${MACHINE_PORTGROUP_REMOTE}
KEEP_HOST_RAW_IMAGE=${KEEP_HOST_RAW_IMAGE_REMOTE}
COPY_BASE_IMAGE=${COPY_BASE_IMAGE_REMOTE}
NODE_1_NAME=${NODE_1_NAME_REMOTE}
NODE_1_MAC=${NODE_1_MAC_REMOTE}
NODE_1_VCPUS=${NODE_1_VCPUS_REMOTE}
NODE_1_MEMORY_MB=${NODE_1_MEMORY_REMOTE}
NODE_1_DISK_SIZE_GB=${NODE_1_DISK_REMOTE}
NODE_2_NAME=${NODE_2_NAME_REMOTE}
NODE_2_MAC=${NODE_2_MAC_REMOTE}
NODE_2_VCPUS=${NODE_2_VCPUS_REMOTE}
NODE_2_MEMORY_MB=${NODE_2_MEMORY_REMOTE}
NODE_2_DISK_SIZE_GB=${NODE_2_DISK_REMOTE}
NODE_3_NAME=${NODE_3_NAME_REMOTE}
NODE_3_MAC=${NODE_3_MAC_REMOTE}
NODE_3_VCPUS=${NODE_3_VCPUS_REMOTE}
NODE_3_MEMORY_MB=${NODE_3_MEMORY_REMOTE}
NODE_3_DISK_SIZE_GB=${NODE_3_DISK_REMOTE}
BASE_RAW="\${OCP_IMAGE_DIR}/appliance.raw"
BASE_QCOW="\${OCP_IMAGE_DIR}/appliance-base.qcow2"
CONFIG_ISO="\${OCP_IMAGE_DIR}/agentconfig.noarch.iso"

#### These steps validate copied appliance artifacts

if [[ "\${COPY_BASE_IMAGE}" == "true" && ! -f "\${BASE_RAW}" ]]; then
    echo "Missing copied appliance.raw at \${BASE_RAW}" >&2
    exit 1
fi

if [[ ! -f "\${CONFIG_ISO}" ]]; then
    echo "Missing copied config ISO at \${CONFIG_ISO}" >&2
    exit 1
fi

#### These steps create a reusable QCOW2 backing image

# The node disks are small overlays backed by the appliance image.
if [[ "\${COPY_BASE_IMAGE}" == "true" ]]; then
    echo "Converting copied appliance.raw into reusable QCOW2 backing image."
    qemu-img convert -f raw -O qcow2 "\${BASE_RAW}" "\${BASE_QCOW}.tmp"
    mv "\${BASE_QCOW}.tmp" "\${BASE_QCOW}"

    if [[ "\${KEEP_HOST_RAW_IMAGE}" == "false" ]]; then
        rm -f "\${BASE_RAW}"
    fi
else
    echo "Using existing reusable QCOW2 backing image: \${BASE_QCOW}"
fi

chown qemu:qemu "\${BASE_QCOW}" "\${CONFIG_ISO}" || true

create_node_vm() {
    local node_name
    local node_mac
    local node_vcpus
    local node_memory
    local node_disk_size
    local node_disk

    node_name="\$1"
    node_mac="\$2"
    node_vcpus="\$3"
    node_memory="\$4"
    node_disk_size="\$5"
    node_disk="\${OCP_IMAGE_DIR}/\${node_name}.qcow2"

    if virsh dominfo "\${node_name}" >/dev/null 2>&1; then
        echo "VM \${node_name} already exists. Run script 14 before reimaging." >&2
        exit 1
    fi

    rm -f "\${node_disk}"
    echo "Creating \${node_name}: \${node_vcpus} vCPU, \${node_memory} MiB RAM, \${node_disk_size} GiB overlay."
    qemu-img create \
        -f qcow2 \
        -F qcow2 \
        -b "\${BASE_QCOW}" \
        "\${node_disk}" \
        "\${node_disk_size}G"
    chown qemu:qemu "\${node_disk}" || true

    virt-install \
        --name "\${node_name}" \
        --memory "\${node_memory}" \
        --vcpus "\${node_vcpus}" \
        --os-variant "\${OCP_OS_VARIANT}" \
        --import \
        --boot uefi \
        --disk "path=\${node_disk},format=qcow2,bus=virtio" \
        --disk "path=\${CONFIG_ISO},device=cdrom,readonly=on" \
        --network "network=\${LIBVIRT_NETWORK},source.portgroup=\${MACHINE_PORTGROUP},model=virtio,mac=\${node_mac}" \
        --graphics vnc,listen=127.0.0.1 \
        --video virtio \
        --console pty,target_type=serial \
        --noautoconsole
}

#### These steps define and boot the three compact-cluster nodes

create_node_vm "\${NODE_1_NAME}" "\${NODE_1_MAC}" "\${NODE_1_VCPUS}" "\${NODE_1_MEMORY_MB}" "\${NODE_1_DISK_SIZE_GB}"
create_node_vm "\${NODE_2_NAME}" "\${NODE_2_MAC}" "\${NODE_2_VCPUS}" "\${NODE_2_MEMORY_MB}" "\${NODE_2_DISK_SIZE_GB}"
create_node_vm "\${NODE_3_NAME}" "\${NODE_3_MAC}" "\${NODE_3_VCPUS}" "\${NODE_3_MEMORY_MB}" "\${NODE_3_DISK_SIZE_GB}"

virsh list --all
echo "OpenShift appliance VMs are defined and running."
REMOTE_SCRIPT
