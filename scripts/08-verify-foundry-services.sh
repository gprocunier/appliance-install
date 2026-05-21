#!/usr/bin/env bash
set -euo pipefail

#### These steps verify the foundry service baseline

# Run this script from the operator workstation, in the repository root.
# This script checks foundry through the virtualization host jump path.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/remote.sh"

load_host_config
load_network_config
load_foundry_config

APPLIANCE_CLUSTER_DOMAIN="${APPLIANCE_CLUSTER_DOMAIN:-appliance.workshop.lan}"
APPLIANCE_MIRROR_REGISTRY_NAME="${APPLIANCE_MIRROR_REGISTRY_NAME:-mirror-registry}"
APPLIANCE_API_IP="${APPLIANCE_API_IP:-172.16.10.5}"
APPLIANCE_INGRESS_IP="${APPLIANCE_INGRESS_IP:-172.16.10.7}"
APPLIANCE_NODE_1_NAME="${APPLIANCE_NODE_1_NAME:-ocp-01}"
APPLIANCE_NODE_2_NAME="${APPLIANCE_NODE_2_NAME:-ocp-02}"
APPLIANCE_NODE_3_NAME="${APPLIANCE_NODE_3_NAME:-ocp-03}"
APPLIANCE_FOUNDRY_HOSTNAME="${APPLIANCE_FOUNDRY_HOSTNAME:-foundry.${APPLIANCE_CLUSTER_DOMAIN}}"

#### These commands intentionally stay simple and readable

# Show foundry identity and interface state.
run_foundry hostnamectl
run_foundry ip -br addr

# Confirm expected services are active.
run_foundry systemctl is-active dnsmasq.service
run_foundry systemctl is-active chronyd.service
run_foundry systemctl is-active httpd.service
run_foundry systemctl is-active firewalld.service

# Confirm local DNS records for the appliance network.
run_foundry dig "@${APPLIANCE_FOUNDRY_APPLIANCE_IP}" "${APPLIANCE_FOUNDRY_HOSTNAME}" +short
run_foundry dig "@${APPLIANCE_FOUNDRY_APPLIANCE_IP}" "${APPLIANCE_MIRROR_REGISTRY_NAME}.${APPLIANCE_CLUSTER_DOMAIN}" +short
run_foundry dig "@${APPLIANCE_FOUNDRY_APPLIANCE_IP}" "api.${APPLIANCE_CLUSTER_DOMAIN}" +short
run_foundry dig "@${APPLIANCE_FOUNDRY_APPLIANCE_IP}" "api-int.${APPLIANCE_CLUSTER_DOMAIN}" +short
run_foundry dig "@${APPLIANCE_FOUNDRY_APPLIANCE_IP}" "console-openshift-console.apps.${APPLIANCE_CLUSTER_DOMAIN}" +short
run_foundry dig "@${APPLIANCE_FOUNDRY_APPLIANCE_IP}" "${APPLIANCE_NODE_1_NAME}.${APPLIANCE_CLUSTER_DOMAIN}" +short
run_foundry dig "@${APPLIANCE_FOUNDRY_APPLIANCE_IP}" "${APPLIANCE_NODE_2_NAME}.${APPLIANCE_CLUSTER_DOMAIN}" +short
run_foundry dig "@${APPLIANCE_FOUNDRY_APPLIANCE_IP}" "${APPLIANCE_NODE_3_NAME}.${APPLIANCE_CLUSTER_DOMAIN}" +short

# Confirm NTP and web staging endpoints respond.
run_foundry chronyc tracking
run_foundry curl -I "http://127.0.0.1/assets/"

# Show the foundry firewall state for operator review.
run_foundry sudo -n firewall-cmd --list-all
