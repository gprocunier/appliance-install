#!/usr/bin/env bash
set -euo pipefail

#### These steps prepare OpenShift appliance build assets on foundry

# Run this script from the operator workstation, in the repository root.
# This script copies local-only secrets to foundry and writes generated YAML.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/remote.sh"

load_host_config
load_network_config
load_foundry_config
load_appliance_config

APPLIANCE_CLUSTER_DOMAIN="${APPLIANCE_CLUSTER_DOMAIN:-appliance.workshop.lan}"
APPLIANCE_CLUSTER_NAME="${APPLIANCE_CLUSTER_NAME:-appliance}"
APPLIANCE_BASE_DOMAIN="${APPLIANCE_BASE_DOMAIN:-workshop.lan}"
APPLIANCE_OCP_VERSION="${APPLIANCE_OCP_VERSION:-4.21}"
APPLIANCE_OCP_CHANNEL="${APPLIANCE_OCP_CHANNEL:-stable}"
APPLIANCE_OCP_CPU_ARCHITECTURE="${APPLIANCE_OCP_CPU_ARCHITECTURE:-x86_64}"
APPLIANCE_IMAGE_DISK_SIZE_GB="${APPLIANCE_IMAGE_DISK_SIZE_GB:-200}"
APPLIANCE_BUILDER_IMAGE="${APPLIANCE_BUILDER_IMAGE:-quay.io/edge-infrastructure/openshift-appliance:latest}"
APPLIANCE_ASSETS_DIR="${APPLIANCE_ASSETS_DIR:-/srv/appliance/assets}"
APPLIANCE_CLUSTER_CONFIG_DIR="${APPLIANCE_CLUSTER_CONFIG_DIR:-/srv/appliance/cluster-config}"
APPLIANCE_PULL_SECRET_FILE="${APPLIANCE_PULL_SECRET_FILE:-}"
APPLIANCE_CORE_PASSWORD="${APPLIANCE_CORE_PASSWORD:-}"
APPLIANCE_CORE_SSH_PUBLIC_KEY_FILE="${APPLIANCE_CORE_SSH_PUBLIC_KEY_FILE:-${APPLIANCE_FOUNDRY_SSH_PUBLIC_KEY_FILE:-}}"
APPLIANCE_MACHINE_NETWORK_CIDR="${APPLIANCE_MACHINE_NETWORK_CIDR:-172.16.10.0/24}"
APPLIANCE_RENDEZVOUS_IP="${APPLIANCE_RENDEZVOUS_IP:-${APPLIANCE_NODE_1_IP:-172.16.10.11}}"
APPLIANCE_NODE_INTERFACE="${APPLIANCE_NODE_INTERFACE:-enp1s0}"
APPLIANCE_AGENT_NTP_SOURCE="${APPLIANCE_AGENT_NTP_SOURCE:-${APPLIANCE_FOUNDRY_APPLIANCE_IP}}"

APPLIANCE_NODE_1_MAC="${APPLIANCE_NODE_1_MAC:-52:54:00:10:11:11}"
APPLIANCE_NODE_2_MAC="${APPLIANCE_NODE_2_MAC:-52:54:00:10:11:12}"
APPLIANCE_NODE_3_MAC="${APPLIANCE_NODE_3_MAC:-52:54:00:10:11:13}"
APPLIANCE_NODE_1_DISK_SIZE_GB="${APPLIANCE_NODE_1_DISK_SIZE_GB:-200}"
APPLIANCE_NODE_2_DISK_SIZE_GB="${APPLIANCE_NODE_2_DISK_SIZE_GB:-200}"
APPLIANCE_NODE_3_DISK_SIZE_GB="${APPLIANCE_NODE_3_DISK_SIZE_GB:-200}"

APPLIANCE_MACHINE_GATEWAY_IP="${APPLIANCE_MACHINE_GATEWAY_CIDR%/*}"
APPLIANCE_MACHINE_PREFIX="${APPLIANCE_MACHINE_GATEWAY_CIDR#*/}"

load_operator_config
APPLIANCE_OPERATOR_PACKAGES_PAYLOAD="$(operator_packages_payload)"

#### These steps validate appliance build settings before making changes

# The appliance disk image requires at least 150 GiB.
validate_positive_integer "APPLIANCE_IMAGE_DISK_SIZE_GB" "${APPLIANCE_IMAGE_DISK_SIZE_GB}"
if (( 10#${APPLIANCE_IMAGE_DISK_SIZE_GB} < 150 )); then
    fail "APPLIANCE_IMAGE_DISK_SIZE_GB must be at least 150 for OpenShift Appliance."
fi

# Cluster VM disks must be at least as large as the appliance image.
for node_disk in \
    "${APPLIANCE_NODE_1_DISK_SIZE_GB}" \
    "${APPLIANCE_NODE_2_DISK_SIZE_GB}" \
    "${APPLIANCE_NODE_3_DISK_SIZE_GB}"
do
    validate_positive_integer "APPLIANCE_NODE_DISK_SIZE_GB" "${node_disk}"
    if (( 10#${node_disk} < 10#${APPLIANCE_IMAGE_DISK_SIZE_GB} )); then
        fail "Each OpenShift node disk must be at least APPLIANCE_IMAGE_DISK_SIZE_GB."
    fi
done

validate_non_empty "APPLIANCE_BUILDER_IMAGE" "${APPLIANCE_BUILDER_IMAGE}"
validate_absolute_path "APPLIANCE_ASSETS_DIR" "${APPLIANCE_ASSETS_DIR}"
validate_absolute_path "APPLIANCE_CLUSTER_CONFIG_DIR" "${APPLIANCE_CLUSTER_CONFIG_DIR}"
validate_non_empty "APPLIANCE_PULL_SECRET_FILE" "${APPLIANCE_PULL_SECRET_FILE}"
validate_non_empty "APPLIANCE_CORE_PASSWORD" "${APPLIANCE_CORE_PASSWORD}"
validate_non_empty "APPLIANCE_CORE_SSH_PUBLIC_KEY_FILE" "${APPLIANCE_CORE_SSH_PUBLIC_KEY_FILE}"
validate_dns_label "APPLIANCE_CLUSTER_NAME" "${APPLIANCE_CLUSTER_NAME}"
validate_fqdn "APPLIANCE_BASE_DOMAIN" "${APPLIANCE_BASE_DOMAIN}"
validate_fqdn "APPLIANCE_CLUSTER_DOMAIN" "${APPLIANCE_CLUSTER_DOMAIN}"
validate_ipv4_cidr "APPLIANCE_MACHINE_NETWORK_CIDR" "${APPLIANCE_MACHINE_NETWORK_CIDR}"
validate_ipv4 "APPLIANCE_MACHINE_GATEWAY_IP" "${APPLIANCE_MACHINE_GATEWAY_IP}"
validate_ipv4_prefix "APPLIANCE_MACHINE_PREFIX" "${APPLIANCE_MACHINE_PREFIX}"
validate_ipv4 "APPLIANCE_RENDEZVOUS_IP" "${APPLIANCE_RENDEZVOUS_IP}"
validate_simple_name "APPLIANCE_NODE_INTERFACE" "${APPLIANCE_NODE_INTERFACE}"
validate_non_empty "APPLIANCE_AGENT_NTP_SOURCE" "${APPLIANCE_AGENT_NTP_SOURCE}"
validate_mac "APPLIANCE_NODE_1_MAC" "${APPLIANCE_NODE_1_MAC}"
validate_mac "APPLIANCE_NODE_2_MAC" "${APPLIANCE_NODE_2_MAC}"
validate_mac "APPLIANCE_NODE_3_MAC" "${APPLIANCE_NODE_3_MAC}"
validate_non_empty "APPLIANCE_OPERATOR_PACKAGES_PAYLOAD" "${APPLIANCE_OPERATOR_PACKAGES_PAYLOAD}"

if [[ "${APPLIANCE_CORE_PASSWORD}" == replace-with-* ]]; then
    fail "APPLIANCE_CORE_PASSWORD must be changed in config/appliance.env."
fi

if [[ "${APPLIANCE_CORE_PASSWORD}" == *$'\n'* ]]; then
    fail "APPLIANCE_CORE_PASSWORD must be a single-line value."
fi

if [[ ! -f "${APPLIANCE_PULL_SECRET_FILE}" ]]; then
    fail "Missing APPLIANCE_PULL_SECRET_FILE: ${APPLIANCE_PULL_SECRET_FILE}"
fi

if [[ ! -f "${APPLIANCE_CORE_SSH_PUBLIC_KEY_FILE}" ]]; then
    fail "Missing APPLIANCE_CORE_SSH_PUBLIC_KEY_FILE: ${APPLIANCE_CORE_SSH_PUBLIC_KEY_FILE}"
fi

APPLIANCE_CORE_SSH_PUBLIC_KEY="$(<"${APPLIANCE_CORE_SSH_PUBLIC_KEY_FILE}")"
validate_ssh_public_key "APPLIANCE_CORE_SSH_PUBLIC_KEY" "${APPLIANCE_CORE_SSH_PUBLIC_KEY}"

#### These steps copy the pull secret into ignored foundry-local paths

# The real pull secret never enters tracked files.
echo "Copying the pull secret to foundry-local ignored paths."
ssh_config="$(mktemp)"
write_foundry_ssh_config "${ssh_config}"

ssh -F "${ssh_config}" appliance-foundry \
    'mkdir -p ~/.config/containers && chmod 700 ~/.config/containers && cat > ~/.config/containers/auth.json && chmod 600 ~/.config/containers/auth.json' \
    < "${APPLIANCE_PULL_SECRET_FILE}"

rm -f "${ssh_config}"

printf -v OCP_VERSION_REMOTE '%q' "${APPLIANCE_OCP_VERSION}"
printf -v OCP_CHANNEL_REMOTE '%q' "${APPLIANCE_OCP_CHANNEL}"
printf -v OCP_ARCH_REMOTE '%q' "${APPLIANCE_OCP_CPU_ARCHITECTURE}"
printf -v IMAGE_DISK_SIZE_REMOTE '%q' "${APPLIANCE_IMAGE_DISK_SIZE_GB}"
printf -v BUILDER_IMAGE_REMOTE '%q' "${APPLIANCE_BUILDER_IMAGE}"
printf -v ASSETS_DIR_REMOTE '%q' "${APPLIANCE_ASSETS_DIR}"
printf -v CLUSTER_CONFIG_DIR_REMOTE '%q' "${APPLIANCE_CLUSTER_CONFIG_DIR}"
printf -v CORE_PASSWORD_REMOTE '%q' "${APPLIANCE_CORE_PASSWORD}"
printf -v CORE_SSH_KEY_REMOTE '%q' "${APPLIANCE_CORE_SSH_PUBLIC_KEY}"
printf -v CLUSTER_NAME_REMOTE '%q' "${APPLIANCE_CLUSTER_NAME}"
printf -v BASE_DOMAIN_REMOTE '%q' "${APPLIANCE_BASE_DOMAIN}"
printf -v CLUSTER_DOMAIN_REMOTE '%q' "${APPLIANCE_CLUSTER_DOMAIN}"
printf -v MACHINE_NETWORK_REMOTE '%q' "${APPLIANCE_MACHINE_NETWORK_CIDR}"
printf -v MACHINE_PREFIX_REMOTE '%q' "${APPLIANCE_MACHINE_PREFIX}"
printf -v MACHINE_GATEWAY_REMOTE '%q' "${APPLIANCE_MACHINE_GATEWAY_IP}"
printf -v DNS_SERVER_REMOTE '%q' "${APPLIANCE_FOUNDRY_APPLIANCE_IP}"
printf -v API_VIP_REMOTE '%q' "${APPLIANCE_API_IP}"
printf -v INGRESS_VIP_REMOTE '%q' "${APPLIANCE_INGRESS_IP}"
printf -v RENDEZVOUS_IP_REMOTE '%q' "${APPLIANCE_RENDEZVOUS_IP}"
printf -v NODE_INTERFACE_REMOTE '%q' "${APPLIANCE_NODE_INTERFACE}"
printf -v NTP_SOURCE_REMOTE '%q' "${APPLIANCE_AGENT_NTP_SOURCE}"
printf -v NODE_1_NAME_REMOTE '%q' "${APPLIANCE_NODE_1_NAME}"
printf -v NODE_1_IP_REMOTE '%q' "${APPLIANCE_NODE_1_IP}"
printf -v NODE_1_MAC_REMOTE '%q' "${APPLIANCE_NODE_1_MAC}"
printf -v NODE_2_NAME_REMOTE '%q' "${APPLIANCE_NODE_2_NAME}"
printf -v NODE_2_IP_REMOTE '%q' "${APPLIANCE_NODE_2_IP}"
printf -v NODE_2_MAC_REMOTE '%q' "${APPLIANCE_NODE_2_MAC}"
printf -v NODE_3_NAME_REMOTE '%q' "${APPLIANCE_NODE_3_NAME}"
printf -v NODE_3_IP_REMOTE '%q' "${APPLIANCE_NODE_3_IP}"
printf -v NODE_3_MAC_REMOTE '%q' "${APPLIANCE_NODE_3_MAC}"
printf -v OPERATOR_PACKAGES_REMOTE '%q' "${APPLIANCE_OPERATOR_PACKAGES_PAYLOAD}"

run_foundry sudo -n /bin/bash -s <<REMOTE_SCRIPT
set -euo pipefail

OCP_VERSION=${OCP_VERSION_REMOTE}
OCP_CHANNEL=${OCP_CHANNEL_REMOTE}
OCP_ARCH=${OCP_ARCH_REMOTE}
IMAGE_DISK_SIZE_GB=${IMAGE_DISK_SIZE_REMOTE}
BUILDER_IMAGE=${BUILDER_IMAGE_REMOTE}
ASSETS_DIR=${ASSETS_DIR_REMOTE}
CLUSTER_CONFIG_DIR=${CLUSTER_CONFIG_DIR_REMOTE}
CORE_PASSWORD=${CORE_PASSWORD_REMOTE}
CORE_SSH_KEY=${CORE_SSH_KEY_REMOTE}
CLUSTER_NAME=${CLUSTER_NAME_REMOTE}
BASE_DOMAIN=${BASE_DOMAIN_REMOTE}
CLUSTER_DOMAIN=${CLUSTER_DOMAIN_REMOTE}
MACHINE_NETWORK=${MACHINE_NETWORK_REMOTE}
MACHINE_PREFIX=${MACHINE_PREFIX_REMOTE}
MACHINE_GATEWAY=${MACHINE_GATEWAY_REMOTE}
DNS_SERVER=${DNS_SERVER_REMOTE}
API_VIP=${API_VIP_REMOTE}
INGRESS_VIP=${INGRESS_VIP_REMOTE}
RENDEZVOUS_IP=${RENDEZVOUS_IP_REMOTE}
NODE_INTERFACE=${NODE_INTERFACE_REMOTE}
NTP_SOURCE=${NTP_SOURCE_REMOTE}
NODE_1_NAME=${NODE_1_NAME_REMOTE}
NODE_1_IP=${NODE_1_IP_REMOTE}
NODE_1_MAC=${NODE_1_MAC_REMOTE}
NODE_2_NAME=${NODE_2_NAME_REMOTE}
NODE_2_IP=${NODE_2_IP_REMOTE}
NODE_2_MAC=${NODE_2_MAC_REMOTE}
NODE_3_NAME=${NODE_3_NAME_REMOTE}
NODE_3_IP=${NODE_3_IP_REMOTE}
NODE_3_MAC=${NODE_3_MAC_REMOTE}
OPERATOR_PACKAGES=${OPERATOR_PACKAGES_REMOTE}
PULL_SECRET_PATH=/home/appliance/.config/containers/auth.json

#### These steps create the asset and cluster config directories

# Keep build inputs under foundry's staging tree.
echo "Creating foundry appliance asset directories."
mkdir -p "\${ASSETS_DIR}/openshift"
mkdir -p "\${ASSETS_DIR}/cache"
mkdir -p "\${CLUSTER_CONFIG_DIR}/openshift"
mkdir -p /srv/appliance/secrets
cp "\${PULL_SECRET_PATH}" /srv/appliance/secrets/pull-secret.txt
chmod 0600 /srv/appliance/secrets/pull-secret.txt

#### These steps write appliance-config.yaml

# The appliance config includes real pull-secret content and is not tracked.
echo "Writing \${ASSETS_DIR}/appliance-config.yaml."
export OCP_VERSION OCP_CHANNEL OCP_ARCH IMAGE_DISK_SIZE_GB BUILDER_IMAGE
export ASSETS_DIR CORE_PASSWORD CORE_SSH_KEY PULL_SECRET_PATH OPERATOR_PACKAGES
python3 - <<'PY'
import os
from pathlib import Path
from collections import OrderedDict

def squote(value):
    return "'" + value.replace("'", "''") + "'"

pull_secret = Path(os.environ["PULL_SECRET_PATH"]).read_text().strip()
operator_catalogs = OrderedDict()

for line in os.environ["OPERATOR_PACKAGES"].splitlines():
    catalog, package, channel = line.split("|", 2)
    operator_catalogs.setdefault(catalog, []).append((package, channel))

lines = [
    "apiVersion: v1beta1",
    "kind: ApplianceConfig",
    "ocpRelease:",
    f"  version: {os.environ['OCP_VERSION']}",
    f"  channel: {os.environ['OCP_CHANNEL']}",
    f"  cpuArchitecture: {os.environ['OCP_ARCH']}",
    f"diskSizeGB: {os.environ['IMAGE_DISK_SIZE_GB']}",
    f"pullSecret: {squote(pull_secret)}",
    f"sshKey: {squote(os.environ['CORE_SSH_KEY'])}",
    f"userCorePass: {squote(os.environ['CORE_PASSWORD'])}",
    "imageRegistry:",
    "  port: 5005",
    "  useBinary: true",
    "enableDefaultSources: false",
    "stopLocalRegistry: false",
    "createPinnedImageSets: false",
    "enableInteractiveFlow: false",
    "useDefaultSourceNames: true",
    "disableSigstoreForAdditionalImages: true",
    "operators:",
]

for catalog, packages in operator_catalogs.items():
    lines.extend([
        f"- catalog: {catalog}",
        "  packages:",
    ])
    for name, channel in packages:
        lines.extend([
            f"  - name: {name}",
            "    channels:",
            f"    - name: {channel}",
        ])

Path(os.environ["ASSETS_DIR"], "appliance-config.yaml").write_text("\n".join(lines) + "\n")
PY

#### These steps write install-config.yaml

# The config image uses a dummy pull secret because the appliance is disconnected.
echo "Writing \${CLUSTER_CONFIG_DIR}/install-config.yaml."
cat > "\${CLUSTER_CONFIG_DIR}/install-config.yaml" <<INSTALL_CONFIG
apiVersion: v1
metadata:
  name: \${CLUSTER_NAME}
baseDomain: \${BASE_DOMAIN}
controlPlane:
  name: master
  replicas: 3
compute:
- name: worker
  replicas: 0
networking:
  networkType: OVNKubernetes
  machineNetwork:
  - cidr: \${MACHINE_NETWORK}
platform:
  baremetal:
    apiVIPs:
    - \${API_VIP}
    ingressVIPs:
    - \${INGRESS_VIP}
pullSecret: '{"auths":{"":{"auth":"dXNlcjpwYXNz"}}}'
sshKey: '\${CORE_SSH_KEY}'
INSTALL_CONFIG

#### These steps write agent-config.yaml

# Static host networking keeps the lab independent of DHCP.
echo "Writing \${CLUSTER_CONFIG_DIR}/agent-config.yaml."
write_agent_host() {
    local node_name
    local node_ip
    local node_mac

    node_name="\$1"
    node_ip="\$2"
    node_mac="\$3"

    cat <<AGENT_HOST
- hostname: \${node_name}
  role: master
  interfaces:
  - name: \${NODE_INTERFACE}
    macAddress: \${node_mac}
  networkConfig:
    interfaces:
    - name: \${NODE_INTERFACE}
      type: ethernet
      state: up
      mac-address: \${node_mac}
      ipv4:
        enabled: true
        dhcp: false
        address:
        - ip: \${node_ip}
          prefix-length: \${MACHINE_PREFIX}
    dns-resolver:
      config:
        server:
        - \${DNS_SERVER}
    routes:
      config:
      - destination: 0.0.0.0/0
        next-hop-address: \${MACHINE_GATEWAY}
        next-hop-interface: \${NODE_INTERFACE}
        table-id: 254
AGENT_HOST
}

{
    cat <<AGENT_CONFIG
apiVersion: v1alpha1
kind: AgentConfig
metadata:
  name: \${CLUSTER_NAME}
rendezvousIP: \${RENDEZVOUS_IP}
additionalNTPSources:
- \${NTP_SOURCE}
hosts:
AGENT_CONFIG

    write_agent_host "\${NODE_1_NAME}" "\${NODE_1_IP}" "\${NODE_1_MAC}"
    write_agent_host "\${NODE_2_NAME}" "\${NODE_2_IP}" "\${NODE_2_MAC}"
    write_agent_host "\${NODE_3_NAME}" "\${NODE_3_IP}" "\${NODE_3_MAC}"
} > "\${CLUSTER_CONFIG_DIR}/agent-config.yaml"

echo "Prepared appliance assets in \${ASSETS_DIR}."
echo "Prepared cluster config in \${CLUSTER_CONFIG_DIR}."
REMOTE_SCRIPT
