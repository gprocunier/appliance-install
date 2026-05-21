#!/usr/bin/env bash
set -euo pipefail

#### These steps remove the OpenShift appliance VMs for a clean reimage

# Run this script from the operator workstation, in the repository root.
# It removes ocp-01, ocp-02, and ocp-03 overlays but keeps the base appliance image.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/remote.sh"

load_host_config
load_foundry_config
load_appliance_config

APPLIANCE_OCP_IMAGE_DIR="${APPLIANCE_OCP_IMAGE_DIR:-/home/libvirt/images/appliance-install}"

validate_absolute_path "APPLIANCE_OCP_IMAGE_DIR" "${APPLIANCE_OCP_IMAGE_DIR}"
validate_dns_label "APPLIANCE_NODE_1_NAME" "${APPLIANCE_NODE_1_NAME}"
validate_dns_label "APPLIANCE_NODE_2_NAME" "${APPLIANCE_NODE_2_NAME}"
validate_dns_label "APPLIANCE_NODE_3_NAME" "${APPLIANCE_NODE_3_NAME}"

printf -v OCP_IMAGE_DIR_REMOTE '%q' "${APPLIANCE_OCP_IMAGE_DIR}"
printf -v NODE_1_NAME_REMOTE '%q' "${APPLIANCE_NODE_1_NAME}"
printf -v NODE_2_NAME_REMOTE '%q' "${APPLIANCE_NODE_2_NAME}"
printf -v NODE_3_NAME_REMOTE '%q' "${APPLIANCE_NODE_3_NAME}"

run_remote_bash <<REMOTE_SCRIPT
set -euo pipefail

OCP_IMAGE_DIR=${OCP_IMAGE_DIR_REMOTE}
NODE_1_NAME=${NODE_1_NAME_REMOTE}
NODE_2_NAME=${NODE_2_NAME_REMOTE}
NODE_3_NAME=${NODE_3_NAME_REMOTE}

destroy_node_vm() {
    local node_name
    local node_disk

    node_name="\$1"
    node_disk="\${OCP_IMAGE_DIR}/\${node_name}.qcow2"

    if virsh dominfo "\${node_name}" >/dev/null 2>&1; then
        virsh destroy "\${node_name}" >/dev/null 2>&1 || true
        virsh undefine "\${node_name}" --nvram >/dev/null 2>&1 || \
            virsh undefine "\${node_name}" >/dev/null 2>&1 || true
    fi

    rm -f "\${node_disk}"
}

#### These steps destroy node domains and remove only their overlay disks

destroy_node_vm "\${NODE_1_NAME}"
destroy_node_vm "\${NODE_2_NAME}"
destroy_node_vm "\${NODE_3_NAME}"

virsh list --all
echo "OpenShift appliance VMs were removed. Re-run script 13 to reimage."
REMOTE_SCRIPT
