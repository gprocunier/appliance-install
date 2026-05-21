#!/usr/bin/env bash
set -euo pipefail

#### These steps build the OpenShift appliance disk image on standalone foundry

# Run this script from the operator workstation, in the repository root.
# The build runs inside the appliance builder container on the standalone host.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/standalone.sh"

load_standalone_config
validate_standalone_config
load_appliance_config

APPLIANCE_BUILDER_IMAGE="${APPLIANCE_BUILDER_IMAGE:-quay.io/edge-infrastructure/openshift-appliance:latest}"
APPLIANCE_ASSETS_DIR="${APPLIANCE_ASSETS_DIR:-/srv/appliance/assets}"
APPLIANCE_CLEAN_BEFORE_BUILD="${APPLIANCE_CLEAN_BEFORE_BUILD:-false}"
APPLIANCE_BUILD_LOG_LEVEL="${APPLIANCE_BUILD_LOG_LEVEL:-info}"

#### These steps validate build settings before starting the long build

validate_non_empty "APPLIANCE_BUILDER_IMAGE" "${APPLIANCE_BUILDER_IMAGE}"
validate_absolute_path "APPLIANCE_ASSETS_DIR" "${APPLIANCE_ASSETS_DIR}"
validate_boolean "APPLIANCE_CLEAN_BEFORE_BUILD" "${APPLIANCE_CLEAN_BEFORE_BUILD}"
validate_non_empty "APPLIANCE_BUILD_LOG_LEVEL" "${APPLIANCE_BUILD_LOG_LEVEL}"

printf -v BUILDER_IMAGE_REMOTE '%q' "${APPLIANCE_BUILDER_IMAGE}"
printf -v ASSETS_DIR_REMOTE '%q' "${APPLIANCE_ASSETS_DIR}"
printf -v CLEAN_BEFORE_BUILD_REMOTE '%q' "${APPLIANCE_CLEAN_BEFORE_BUILD}"
printf -v BUILD_LOG_LEVEL_REMOTE '%q' "${APPLIANCE_BUILD_LOG_LEVEL}"

run_standalone_root_bash <<REMOTE_SCRIPT
set -euo pipefail

BUILDER_IMAGE=${BUILDER_IMAGE_REMOTE}
ASSETS_DIR=${ASSETS_DIR_REMOTE}
CLEAN_BEFORE_BUILD=${CLEAN_BEFORE_BUILD_REMOTE}
BUILD_LOG_LEVEL=${BUILD_LOG_LEVEL_REMOTE}

#### These steps validate standalone build inputs

# The generated appliance config contains pull-secret content and stays remote.
if [[ ! -f "\${ASSETS_DIR}/appliance-config.yaml" ]]; then
    echo "Missing \${ASSETS_DIR}/appliance-config.yaml. Run script 04 first." >&2
    exit 1
fi

echo "Standalone appliance build workspace:"
df -h "\${ASSETS_DIR}" /
echo

#### These steps pull the appliance builder container

# Pulling the builder can take a few minutes the first time.
echo "Pulling appliance builder image: \${BUILDER_IMAGE}"
podman pull "\${BUILDER_IMAGE}"
echo

#### These steps optionally clean previous temporary build output

if [[ "\${CLEAN_BEFORE_BUILD}" == "true" ]]; then
    echo "Cleaning previous appliance-builder temporary output."
    podman run --rm \
        --privileged \
        --net=host \
        -v "\${ASSETS_DIR}:/assets:Z" \
        "\${BUILDER_IMAGE}" \
        clean
    echo
fi

#### These steps build appliance.raw

# The build mirrors OCP, operator content, and any additional images.
echo "Starting standalone appliance image build at \$(date -Is)."
echo "This phase mirrors OpenShift, operator, and additional image content into \${ASSETS_DIR}."
echo "Builder log on standalone host: \${ASSETS_DIR}/.openshift_appliance.log"
echo "oc-mirror logs on standalone host: \${ASSETS_DIR}/temp/oc-mirror/working-dir/logs/"
podman run --rm \
    --pull newer \
    --privileged \
    --net=host \
    -v "\${ASSETS_DIR}:/assets:Z" \
    "\${BUILDER_IMAGE}" \
    --log-level "\${BUILD_LOG_LEVEL}" \
    build

chmod 0644 "\${ASSETS_DIR}/appliance.raw"
qemu-img info "\${ASSETS_DIR}/appliance.raw"
ls -lh "\${ASSETS_DIR}/appliance.raw"
echo "Standalone OpenShift appliance image build is complete."
REMOTE_SCRIPT
