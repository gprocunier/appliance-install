#!/usr/bin/env bash
set -euo pipefail

#### These steps create the Agent Installer config ISO on foundry

# Run this script from the operator workstation, in the repository root.
# The config ISO is mounted by every OpenShift VM during appliance installation.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/remote.sh"

load_host_config
load_network_config
load_foundry_config
load_appliance_config

APPLIANCE_OCP_VERSION="${APPLIANCE_OCP_VERSION:-4.21}"
APPLIANCE_OCP_CPU_ARCHITECTURE="${APPLIANCE_OCP_CPU_ARCHITECTURE:-x86_64}"
APPLIANCE_ASSETS_DIR="${APPLIANCE_ASSETS_DIR:-/srv/appliance/assets}"
APPLIANCE_CLUSTER_CONFIG_DIR="${APPLIANCE_CLUSTER_CONFIG_DIR:-/srv/appliance/cluster-config}"
APPLIANCE_FOUNDRY_HTTP_ROOT="${APPLIANCE_FOUNDRY_HTTP_ROOT:-/srv/appliance}"

#### These steps validate config-image settings

validate_non_empty "APPLIANCE_OCP_VERSION" "${APPLIANCE_OCP_VERSION}"
validate_non_empty "APPLIANCE_OCP_CPU_ARCHITECTURE" "${APPLIANCE_OCP_CPU_ARCHITECTURE}"
validate_absolute_path "APPLIANCE_ASSETS_DIR" "${APPLIANCE_ASSETS_DIR}"
validate_absolute_path "APPLIANCE_CLUSTER_CONFIG_DIR" "${APPLIANCE_CLUSTER_CONFIG_DIR}"
validate_absolute_path "APPLIANCE_FOUNDRY_HTTP_ROOT" "${APPLIANCE_FOUNDRY_HTTP_ROOT}"

printf -v OCP_VERSION_REMOTE '%q' "${APPLIANCE_OCP_VERSION}"
printf -v OCP_ARCH_REMOTE '%q' "${APPLIANCE_OCP_CPU_ARCHITECTURE}"
printf -v ASSETS_DIR_REMOTE '%q' "${APPLIANCE_ASSETS_DIR}"
printf -v CLUSTER_CONFIG_DIR_REMOTE '%q' "${APPLIANCE_CLUSTER_CONFIG_DIR}"
printf -v HTTP_ROOT_REMOTE '%q' "${APPLIANCE_FOUNDRY_HTTP_ROOT}"

run_foundry sudo -n /bin/bash -s <<REMOTE_SCRIPT
set -euo pipefail

OCP_VERSION=${OCP_VERSION_REMOTE}
OCP_ARCH=${OCP_ARCH_REMOTE}
ASSETS_DIR=${ASSETS_DIR_REMOTE}
CLUSTER_CONFIG_DIR=${CLUSTER_CONFIG_DIR_REMOTE}
HTTP_ROOT=${HTTP_ROOT_REMOTE}
INSTALLER_DIR="\${HTTP_ROOT}/bin/openshift-install-\${OCP_VERSION}"
INSTALLER="\${INSTALLER_DIR}/openshift-install"
INSTALLER_URL="https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest-\${OCP_VERSION}/openshift-install-linux.tar.gz"

restore_cluster_config() {
    if [[ -f "\${CLUSTER_CONFIG_DIR}/install-config.yaml.generated" ]]; then
        cp "\${CLUSTER_CONFIG_DIR}/install-config.yaml.generated" "\${CLUSTER_CONFIG_DIR}/install-config.yaml"
    fi

    if [[ -f "\${CLUSTER_CONFIG_DIR}/agent-config.yaml.generated" ]]; then
        cp "\${CLUSTER_CONFIG_DIR}/agent-config.yaml.generated" "\${CLUSTER_CONFIG_DIR}/agent-config.yaml"
    fi
}

#### These steps validate cluster configuration inputs

restore_cluster_config

if [[ ! -f "\${CLUSTER_CONFIG_DIR}/install-config.yaml" ]]; then
    echo "Missing \${CLUSTER_CONFIG_DIR}/install-config.yaml. Run script 10 first." >&2
    exit 1
fi

if [[ ! -f "\${CLUSTER_CONFIG_DIR}/agent-config.yaml" ]]; then
    echo "Missing \${CLUSTER_CONFIG_DIR}/agent-config.yaml. Run script 10 first." >&2
    exit 1
fi

#### These steps download openshift-install when needed

# Prefer the installer extracted by the appliance builder so config-image
# generation matches the release that produced appliance.raw.
CACHED_INSTALLER=""
if [[ -d "\${ASSETS_DIR}/cache" ]]; then
    while IFS= read -r candidate; do
        candidate_dir="\$(basename "\$(dirname "\${candidate}")")"
        if [[ "\${candidate_dir}" == "\${OCP_VERSION}"*"-\${OCP_ARCH}" ]]; then
            CACHED_INSTALLER="\${candidate}"
        fi
    done < <(find "\${ASSETS_DIR}/cache" -mindepth 2 -maxdepth 2 -type f -name openshift-install | sort -V)
fi

if [[ -n "\${CACHED_INSTALLER}" ]]; then
    echo "Using appliance-builder cached openshift-install: \${CACHED_INSTALLER}"
    mkdir -p "\${INSTALLER_DIR}"
    cp "\${CACHED_INSTALLER}" "\${INSTALLER}"
    chmod 0755 "\${INSTALLER}"
elif [[ ! -x "\${INSTALLER}" ]]; then
    echo "Downloading openshift-install for OpenShift \${OCP_VERSION}."
    mkdir -p "\${INSTALLER_DIR}"
    curl -L "\${INSTALLER_URL}" -o "\${INSTALLER_DIR}/openshift-install-linux.tar.gz"
    tar -xzf "\${INSTALLER_DIR}/openshift-install-linux.tar.gz" -C "\${INSTALLER_DIR}" openshift-install
    chmod 0755 "\${INSTALLER}"
else
    echo "Using existing openshift-install: \${INSTALLER}"
fi

"\${INSTALLER}" version

#### These steps create agentconfig.noarch.iso

# openshift-install consumes the YAML files, so keep restorable copies.
echo "Creating Agent Installer config ISO in \${CLUSTER_CONFIG_DIR}."
cp "\${CLUSTER_CONFIG_DIR}/install-config.yaml" "\${CLUSTER_CONFIG_DIR}/install-config.yaml.generated"
cp "\${CLUSTER_CONFIG_DIR}/agent-config.yaml" "\${CLUSTER_CONFIG_DIR}/agent-config.yaml.generated"
trap restore_cluster_config EXIT

# Remove previous generated installer state so a reimage gets a fresh ISO,
# kubeconfig, and wait-for state from the current YAML inputs.
rm -rf "\${CLUSTER_CONFIG_DIR}/auth" "\${CLUSTER_CONFIG_DIR}/openshift" "\${CLUSTER_CONFIG_DIR}/manifests"
rm -f "\${CLUSTER_CONFIG_DIR}/.openshift_install_state.json"
rm -f "\${CLUSTER_CONFIG_DIR}/.openshift_install.log"
rm -f "\${CLUSTER_CONFIG_DIR}/agentconfig.noarch.iso"
"\${INSTALLER}" agent create config-image --dir "\${CLUSTER_CONFIG_DIR}" --log-level info

restore_cluster_config
trap - EXIT

ls -lh "\${CLUSTER_CONFIG_DIR}/agentconfig.noarch.iso"
echo "Cluster config image is complete."
REMOTE_SCRIPT
