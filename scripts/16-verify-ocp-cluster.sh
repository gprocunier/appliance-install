#!/usr/bin/env bash
set -euo pipefail

#### These steps verify the installed OpenShift appliance cluster

# Run this script from the operator workstation, in the repository root.
# It creates a temporary local tunnel to the API VIP and uses a temp kubeconfig.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/remote.sh"

load_host_config
load_foundry_config
load_appliance_config

APPLIANCE_API_IP="${APPLIANCE_API_IP:-172.16.10.5}"
APPLIANCE_VERIFY_LOCAL_PORT="${APPLIANCE_VERIFY_LOCAL_PORT:-16443}"
APPLIANCE_CLUSTER_CONFIG_DIR="${APPLIANCE_CLUSTER_CONFIG_DIR:-/srv/appliance/cluster-config}"
APPLIANCE_CLUSTER_NAME="${APPLIANCE_CLUSTER_NAME:-appliance}"
APPLIANCE_BASE_DOMAIN="${APPLIANCE_BASE_DOMAIN:-workshop.lan}"
load_operator_config

#### These steps validate local verification requirements

validate_ipv4 "APPLIANCE_API_IP" "${APPLIANCE_API_IP}"
validate_positive_integer "APPLIANCE_VERIFY_LOCAL_PORT" "${APPLIANCE_VERIFY_LOCAL_PORT}"
validate_absolute_path "APPLIANCE_CLUSTER_CONFIG_DIR" "${APPLIANCE_CLUSTER_CONFIG_DIR}"
validate_dns_label "APPLIANCE_CLUSTER_NAME" "${APPLIANCE_CLUSTER_NAME}"
validate_fqdn "APPLIANCE_BASE_DOMAIN" "${APPLIANCE_BASE_DOMAIN}"

if (( 10#${APPLIANCE_VERIFY_LOCAL_PORT} < 1024 || 10#${APPLIANCE_VERIFY_LOCAL_PORT} > 65535 )); then
    fail "APPLIANCE_VERIFY_LOCAL_PORT must be between 1024 and 65535."
fi

if ! command -v oc >/dev/null 2>&1; then
    fail "The oc client must be installed on the operator workstation."
fi

if timeout 1 bash -c ">/dev/tcp/127.0.0.1/${APPLIANCE_VERIFY_LOCAL_PORT}" >/dev/null 2>&1; then
    fail "Local port ${APPLIANCE_VERIFY_LOCAL_PORT} is already in use."
fi

KUBECONFIG_TEMP="$(mktemp)"
SSH_TUNNEL_PID=""

cleanup() {
    if [[ -n "${SSH_TUNNEL_PID}" ]]; then
        kill "${SSH_TUNNEL_PID}" >/dev/null 2>&1 || true
        wait "${SSH_TUNNEL_PID}" >/dev/null 2>&1 || true
    fi

    rm -f "${KUBECONFIG_TEMP}"
}

trap cleanup EXIT

#### These steps copy the kubeconfig into a local temporary file

# The real kubeconfig stays on foundry; the temp copy is deleted on exit.
printf -v CLUSTER_CONFIG_DIR_REMOTE '%q' "${APPLIANCE_CLUSTER_CONFIG_DIR}"
run_foundry sudo -n cat "${CLUSTER_CONFIG_DIR_REMOTE}/auth/kubeconfig" > "${KUBECONFIG_TEMP}"

python3 - "${KUBECONFIG_TEMP}" "${APPLIANCE_VERIFY_LOCAL_PORT}" "${APPLIANCE_CLUSTER_NAME}" "${APPLIANCE_BASE_DOMAIN}" <<'PY'
from pathlib import Path
import sys

kubeconfig = Path(sys.argv[1])
port = sys.argv[2]
cluster_name = sys.argv[3]
base_domain = sys.argv[4]
api_name = f"api.{cluster_name}.{base_domain}"
api_int_name = f"api-int.{cluster_name}.{base_domain}"
text = kubeconfig.read_text()
text = text.replace(f"https://{api_int_name}:6443", f"https://127.0.0.1:{port}")
text = text.replace(f"https://{api_name}:6443", f"https://127.0.0.1:{port}")
kubeconfig.write_text(text)
PY

#### These steps open a temporary API tunnel through the virtualization host

# The API certificate is issued for the cluster names, so oc skips TLS hostname
# verification only for this local tunnel.
if [[ -n "${APPLIANCE_HOST_SSH_KEY:-}" ]]; then
    ssh \
        -i "${APPLIANCE_HOST_SSH_KEY}" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -N \
        -L "${APPLIANCE_VERIFY_LOCAL_PORT}:${APPLIANCE_API_IP}:6443" \
        "$(remote_target)" &
else
    ssh \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -N \
        -L "${APPLIANCE_VERIFY_LOCAL_PORT}:${APPLIANCE_API_IP}:6443" \
        "$(remote_target)" &
fi
SSH_TUNNEL_PID="$!"

for _ in {1..20}; do
    if timeout 1 bash -c ">/dev/tcp/127.0.0.1/${APPLIANCE_VERIFY_LOCAL_PORT}" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

if ! timeout 1 bash -c ">/dev/tcp/127.0.0.1/${APPLIANCE_VERIFY_LOCAL_PORT}" >/dev/null 2>&1; then
    fail "Timed out waiting for the local API tunnel."
fi

#### These steps print the cluster status without exposing credentials

echo "Cluster nodes:"
KUBECONFIG="${KUBECONFIG_TEMP}" oc --insecure-skip-tls-verify=true get nodes -o wide

echo
echo "Cluster version:"
KUBECONFIG="${KUBECONFIG_TEMP}" oc --insecure-skip-tls-verify=true get clusterversion

echo
echo "Cluster operators still progressing or degraded:"
UNHEALTHY_OPERATORS="$(
    KUBECONFIG="${KUBECONFIG_TEMP}" oc --insecure-skip-tls-verify=true get clusteroperators --no-headers | \
        awk '$4 != "False" || $5 != "False" {print}'
)"

if [[ -n "${UNHEALTHY_OPERATORS}" ]]; then
    printf '%s\n' "${UNHEALTHY_OPERATORS}"
else
    echo "All cluster operators report Progressing=False and Degraded=False."
fi

echo
echo "Console URL:"
KUBECONFIG="${KUBECONFIG_TEMP}" oc --insecure-skip-tls-verify=true \
    -n openshift-console get route console \
    -o jsonpath='https://{.spec.host}{"\n"}'

echo
echo "Configured mirrored operator packages:"
while IFS= read -r package; do
    if KUBECONFIG="${KUBECONFIG_TEMP}" oc --insecure-skip-tls-verify=true \
        -n openshift-marketplace get packagemanifest "${package}" >/dev/null 2>&1; then
        echo "${package}: available"
    else
        echo "${package}: not reported by PackageManifest yet"
    fi
done < <(operator_package_names)
