#!/usr/bin/env bash
set -euo pipefail

#### These steps watch the OpenShift appliance installation from foundry

# Run this script from the operator workstation, in the repository root.
# It streams openshift-install wait commands through the foundry jump path.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/remote.sh"

load_host_config
load_network_config
load_foundry_config
load_appliance_config

APPLIANCE_OCP_VERSION="${APPLIANCE_OCP_VERSION:-4.21}"
APPLIANCE_CLUSTER_CONFIG_DIR="${APPLIANCE_CLUSTER_CONFIG_DIR:-/srv/appliance/cluster-config}"
APPLIANCE_FOUNDRY_HTTP_ROOT="${APPLIANCE_FOUNDRY_HTTP_ROOT:-/srv/appliance}"

validate_non_empty "APPLIANCE_OCP_VERSION" "${APPLIANCE_OCP_VERSION}"
validate_absolute_path "APPLIANCE_CLUSTER_CONFIG_DIR" "${APPLIANCE_CLUSTER_CONFIG_DIR}"
validate_absolute_path "APPLIANCE_FOUNDRY_HTTP_ROOT" "${APPLIANCE_FOUNDRY_HTTP_ROOT}"

printf -v OCP_VERSION_REMOTE '%q' "${APPLIANCE_OCP_VERSION}"
printf -v CLUSTER_CONFIG_DIR_REMOTE '%q' "${APPLIANCE_CLUSTER_CONFIG_DIR}"
printf -v HTTP_ROOT_REMOTE '%q' "${APPLIANCE_FOUNDRY_HTTP_ROOT}"

run_foundry sudo -n /bin/bash -s <<REMOTE_SCRIPT
set -euo pipefail

OCP_VERSION=${OCP_VERSION_REMOTE}
CLUSTER_CONFIG_DIR=${CLUSTER_CONFIG_DIR_REMOTE}
HTTP_ROOT=${HTTP_ROOT_REMOTE}
INSTALLER="\${HTTP_ROOT}/bin/openshift-install-\${OCP_VERSION}/openshift-install"

restore_review_copy() {
    local name

    for name in install-config.yaml agent-config.yaml; do
        if [[ -f "\${CLUSTER_CONFIG_DIR}/\${name}.review-copy" ]]; then
            mv -f "\${CLUSTER_CONFIG_DIR}/\${name}.review-copy" "\${CLUSTER_CONFIG_DIR}/\${name}"
        fi
    done
}

#### These steps validate install-watch inputs

if [[ ! -x "\${INSTALLER}" ]]; then
    echo "Missing openshift-install at \${INSTALLER}. Run script 12 first." >&2
    exit 1
fi

if [[ ! -f "\${CLUSTER_CONFIG_DIR}/auth/kubeconfig" ]]; then
    echo "The kubeconfig is not present yet. Script 12 should have generated the config image first." >&2
fi

#### These steps keep wait-for on the generated installer state

# Script 12 restores YAML files for operator review, but wait-for must use the
# state file produced when openshift-install consumed those YAML inputs.
for name in install-config.yaml agent-config.yaml; do
    if [[ -f "\${CLUSTER_CONFIG_DIR}/\${name}" ]]; then
        mv -f "\${CLUSTER_CONFIG_DIR}/\${name}" "\${CLUSTER_CONFIG_DIR}/\${name}.review-copy"
    fi
done
trap restore_review_copy EXIT

#### These steps wait for bootstrap and install completion

# These commands can run for a long time while the appliance installs the cluster.
"\${INSTALLER}" agent wait-for bootstrap-complete --dir "\${CLUSTER_CONFIG_DIR}" --log-level info
"\${INSTALLER}" agent wait-for install-complete --dir "\${CLUSTER_CONFIG_DIR}" --log-level info

restore_review_copy
trap - EXIT

echo "OpenShift appliance installation completed."
REMOTE_SCRIPT
