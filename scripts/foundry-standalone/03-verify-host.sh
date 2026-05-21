#!/usr/bin/env bash
set -euo pipefail

#### These steps verify the standalone foundry host

# Run this script from the operator workstation, in the repository root.
# This script checks that the host is RHEL 10.x and has flat internet access.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/standalone.sh"

load_standalone_config
validate_standalone_config

run_standalone_root_bash <<'REMOTE_SCRIPT'
set -euo pipefail

#### These steps show host identity and RHEL version

hostnamectl
cat /etc/redhat-release

if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    if [[ "${ID:-}" != "rhel" || "${VERSION_ID%%.*}" != "10" ]]; then
        echo "Expected RHEL 10.x; detected ID=${ID:-unknown} VERSION_ID=${VERSION_ID:-unknown}." >&2
        exit 1
    fi
fi

#### These steps verify flat network and registry reachability

# A standalone foundry host is expected to use its normal default gateway.
ip route show default

# Registry DNS and HTTPS checks should use the host's existing resolver path.
getent hosts registry.redhat.io
getent hosts quay.io
curl -I --connect-timeout 10 https://registry.redhat.io/v2/

#### These steps verify local tools needed for the appliance build

podman info --format '{{.Host.OCIRuntime.Name}}'
skopeo --version
qemu-img --version
python3 --version
df -h /
REMOTE_SCRIPT
