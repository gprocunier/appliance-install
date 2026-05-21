#!/usr/bin/env bash
set -euo pipefail

#### These steps fetch appliance.raw from the standalone foundry host

# Run this script from the operator workstation, in the repository root.
# This script copies the finished raw image back to a local ignored output path.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/standalone.sh"

load_standalone_config
validate_standalone_config
load_appliance_config

APPLIANCE_ASSETS_DIR="${APPLIANCE_ASSETS_DIR:-/srv/appliance/assets}"

#### These steps validate fetch settings before copying large artifacts

validate_absolute_path "APPLIANCE_ASSETS_DIR" "${APPLIANCE_ASSETS_DIR}"
validate_non_empty "APPLIANCE_STANDALONE_LOCAL_OUTPUT_DIR" "${APPLIANCE_STANDALONE_LOCAL_OUTPUT_DIR}"

if ! command -v rsync >/dev/null 2>&1; then
    fail "rsync must be installed on the operator workstation to fetch appliance.raw."
fi

run_standalone test -r "${APPLIANCE_ASSETS_DIR}/appliance.raw"

mkdir -p "${APPLIANCE_STANDALONE_LOCAL_OUTPUT_DIR}"

rsync_ssh=(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
if [[ -n "${APPLIANCE_STANDALONE_SSH_KEY:-}" ]]; then
    rsync_ssh+=(-i "${APPLIANCE_STANDALONE_SSH_KEY}")
fi
printf -v rsync_ssh_command '%q ' "${rsync_ssh[@]}"
rsync_ssh_command="${rsync_ssh_command% }"

#### These steps copy the sparse raw image efficiently

echo "Fetching ${APPLIANCE_ASSETS_DIR}/appliance.raw into ${APPLIANCE_STANDALONE_LOCAL_OUTPUT_DIR}."
rsync -av --sparse \
    -e "${rsync_ssh_command}" \
    "$(standalone_target):${APPLIANCE_ASSETS_DIR}/appliance.raw" \
    "${APPLIANCE_STANDALONE_LOCAL_OUTPUT_DIR}/"

ls -lh "${APPLIANCE_STANDALONE_LOCAL_OUTPUT_DIR}/appliance.raw"
