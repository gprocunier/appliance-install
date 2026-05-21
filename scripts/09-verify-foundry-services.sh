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
APPLIANCE_IDM_DNS_FORWARDERS="${APPLIANCE_IDM_DNS_FORWARDERS:-192.168.122.1}"

#### These steps validate verification targets before running checks

# Validate the names and addresses used by the DNS checks.
validate_fqdn "APPLIANCE_CLUSTER_DOMAIN" "${APPLIANCE_CLUSTER_DOMAIN}"
validate_dns_label "APPLIANCE_MIRROR_REGISTRY_NAME" "${APPLIANCE_MIRROR_REGISTRY_NAME}"
validate_fqdn "APPLIANCE_FOUNDRY_HOSTNAME" "${APPLIANCE_FOUNDRY_HOSTNAME}"
validate_ipv4 "APPLIANCE_FOUNDRY_APPLIANCE_IP" "${APPLIANCE_FOUNDRY_APPLIANCE_IP}"
validate_ipv4 "APPLIANCE_API_IP" "${APPLIANCE_API_IP}"
validate_ipv4 "APPLIANCE_INGRESS_IP" "${APPLIANCE_INGRESS_IP}"
validate_dns_label "APPLIANCE_NODE_1_NAME" "${APPLIANCE_NODE_1_NAME}"
validate_dns_label "APPLIANCE_NODE_2_NAME" "${APPLIANCE_NODE_2_NAME}"
validate_dns_label "APPLIANCE_NODE_3_NAME" "${APPLIANCE_NODE_3_NAME}"
validate_non_empty "APPLIANCE_IDM_DNS_FORWARDERS" "${APPLIANCE_IDM_DNS_FORWARDERS}"

read -r -a idm_dns_forwarders <<< "${APPLIANCE_IDM_DNS_FORWARDERS}"
for idm_dns_forwarder in "${idm_dns_forwarders[@]}"; do
    validate_ipv4 "APPLIANCE_IDM_DNS_FORWARDERS" "${idm_dns_forwarder}"
done

#### These commands intentionally stay simple and readable

# Show foundry identity and interface state.
run_foundry hostnamectl
run_foundry ip -br addr

# Confirm expected services are active.
run_foundry systemctl is-active ipa.service
run_foundry systemctl is-active chronyd.service
run_foundry systemctl is-active httpd.service
run_foundry systemctl is-active firewalld.service
run_foundry sudo -n ipactl status

# Confirm IdM DNS records for the appliance network.
run_foundry dig "@${APPLIANCE_FOUNDRY_APPLIANCE_IP}" "${APPLIANCE_FOUNDRY_HOSTNAME}" +short
run_foundry dig "@${APPLIANCE_FOUNDRY_APPLIANCE_IP}" "${APPLIANCE_MIRROR_REGISTRY_NAME}.${APPLIANCE_CLUSTER_DOMAIN}" +short
run_foundry dig "@${APPLIANCE_FOUNDRY_APPLIANCE_IP}" "api.${APPLIANCE_CLUSTER_DOMAIN}" +short
run_foundry dig "@${APPLIANCE_FOUNDRY_APPLIANCE_IP}" "api-int.${APPLIANCE_CLUSTER_DOMAIN}" +short
run_foundry dig "@${APPLIANCE_FOUNDRY_APPLIANCE_IP}" "console-openshift-console.apps.${APPLIANCE_CLUSTER_DOMAIN}" +short
run_foundry dig "@${APPLIANCE_FOUNDRY_APPLIANCE_IP}" "${APPLIANCE_NODE_1_NAME}.${APPLIANCE_CLUSTER_DOMAIN}" +short
run_foundry dig "@${APPLIANCE_FOUNDRY_APPLIANCE_IP}" "${APPLIANCE_NODE_2_NAME}.${APPLIANCE_CLUSTER_DOMAIN}" +short
run_foundry dig "@${APPLIANCE_FOUNDRY_APPLIANCE_IP}" "${APPLIANCE_NODE_3_NAME}.${APPLIANCE_CLUSTER_DOMAIN}" +short

# Confirm foundry itself can recurse through IdM for Red Hat CDN lookups.
run_foundry getent hosts subscription.rhsm.redhat.com
run_foundry dig "@127.0.0.1" subscription.rhsm.redhat.com +short

# Confirm non-foundry clients cannot use IdM as a general internet resolver.
printf -v FOUNDRY_IP_REMOTE '%q' "${APPLIANCE_FOUNDRY_APPLIANCE_IP}"
run_remote_bash <<REMOTE_DNS_CHECK
set -euo pipefail

FOUNDRY_IP=${FOUNDRY_IP_REMOTE}

python3 - "\${FOUNDRY_IP}" subscription.rhsm.redhat.com <<'PY'
import random
import socket
import struct
import sys

server = sys.argv[1]
name = sys.argv[2]
query_id = random.randrange(0, 65536)

packet = struct.pack("!HHHHHH", query_id, 0x0100, 1, 0, 0, 0)
for label in name.split("."):
    packet += bytes([len(label)]) + label.encode("ascii")
packet += b"\x00" + struct.pack("!HH", 1, 1)

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.settimeout(3)
sock.sendto(packet, (server, 53))
data, _addr = sock.recvfrom(4096)
rcode = struct.unpack("!H", data[2:4])[0] & 0x000f

print(f"external-recursion-rcode={rcode}")

if rcode != 5:
    raise SystemExit("Expected REFUSED response for external recursive DNS query.")
PY
REMOTE_DNS_CHECK

# Confirm NTP and web staging endpoints respond.
run_foundry chronyc tracking
run_foundry curl -I "http://127.0.0.1/assets/"

# Show the foundry firewall state for operator review.
run_foundry sudo -n firewall-cmd --list-all
