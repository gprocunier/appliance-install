#!/usr/bin/env bash
set -euo pipefail

#### These steps prepare OpenShift appliance build assets on a standalone host

# Run this script from the operator workstation, in the repository root.
# This script copies local-only secrets and writes appliance-config.yaml remotely.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/standalone.sh"

load_standalone_config
validate_standalone_config
load_appliance_config

APPLIANCE_OCP_VERSION="${APPLIANCE_OCP_VERSION:-4.21}"
APPLIANCE_OCP_CHANNEL="${APPLIANCE_OCP_CHANNEL:-stable}"
APPLIANCE_OCP_CPU_ARCHITECTURE="${APPLIANCE_OCP_CPU_ARCHITECTURE:-x86_64}"
APPLIANCE_IMAGE_DISK_SIZE_GB="${APPLIANCE_IMAGE_DISK_SIZE_GB:-200}"
APPLIANCE_BUILDER_IMAGE="${APPLIANCE_BUILDER_IMAGE:-quay.io/edge-infrastructure/openshift-appliance:latest}"
APPLIANCE_ASSETS_DIR="${APPLIANCE_ASSETS_DIR:-/srv/appliance/assets}"
APPLIANCE_PULL_SECRET_FILE="${APPLIANCE_PULL_SECRET_FILE:-}"
APPLIANCE_CORE_PASSWORD="${APPLIANCE_CORE_PASSWORD:-}"
APPLIANCE_CORE_SSH_PUBLIC_KEY_FILE="${APPLIANCE_CORE_SSH_PUBLIC_KEY_FILE:-${APPLIANCE_STANDALONE_CORE_SSH_PUBLIC_KEY_FILE}}"

load_operator_config
APPLIANCE_OPERATOR_PACKAGES_PAYLOAD="$(operator_packages_payload)"
load_additional_images_config
APPLIANCE_ADDITIONAL_IMAGES_PAYLOAD="$(additional_images_payload)"

#### These steps validate appliance build settings before making changes

# The appliance disk image requires at least 150 GiB.
validate_positive_integer "APPLIANCE_IMAGE_DISK_SIZE_GB" "${APPLIANCE_IMAGE_DISK_SIZE_GB}"
if (( 10#${APPLIANCE_IMAGE_DISK_SIZE_GB} < 150 )); then
    fail "APPLIANCE_IMAGE_DISK_SIZE_GB must be at least 150 for OpenShift Appliance."
fi

validate_non_empty "APPLIANCE_BUILDER_IMAGE" "${APPLIANCE_BUILDER_IMAGE}"
validate_absolute_path "APPLIANCE_ASSETS_DIR" "${APPLIANCE_ASSETS_DIR}"
validate_non_empty "APPLIANCE_PULL_SECRET_FILE" "${APPLIANCE_PULL_SECRET_FILE}"
validate_non_empty "APPLIANCE_CORE_PASSWORD" "${APPLIANCE_CORE_PASSWORD}"
validate_non_empty "APPLIANCE_CORE_SSH_PUBLIC_KEY_FILE" "${APPLIANCE_CORE_SSH_PUBLIC_KEY_FILE}"
validate_non_empty "APPLIANCE_OPERATOR_PACKAGES_PAYLOAD" "${APPLIANCE_OPERATOR_PACKAGES_PAYLOAD}"

if [[ "${APPLIANCE_CORE_PASSWORD}" == replace-with-* ]]; then
    fail "APPLIANCE_CORE_PASSWORD must be changed in config/appliance.env."
fi

if [[ "${APPLIANCE_CORE_PASSWORD}" == *$'\n'* ]]; then
    fail "APPLIANCE_CORE_PASSWORD must be a single-line value."
fi

if [[ ! -f "${APPLIANCE_CORE_SSH_PUBLIC_KEY_FILE}" ]]; then
    fail "Missing APPLIANCE_CORE_SSH_PUBLIC_KEY_FILE: ${APPLIANCE_CORE_SSH_PUBLIC_KEY_FILE}"
fi

#### These steps validate local-only secret files before copying them

# The pull secret must be valid JSON before the standalone host uses registry auth.
validate_pull_secret_file "${APPLIANCE_PULL_SECRET_FILE}"

APPLIANCE_CORE_SSH_PUBLIC_KEY="$(<"${APPLIANCE_CORE_SSH_PUBLIC_KEY_FILE}")"
validate_ssh_public_key "APPLIANCE_CORE_SSH_PUBLIC_KEY" "${APPLIANCE_CORE_SSH_PUBLIC_KEY}"

#### These steps copy the pull secret into ignored standalone-host paths

# The real pull secret never enters tracked files.
echo "Copying the pull secret to the standalone host."
remote_pull_secret="/tmp/appliance-pull-secret.$$"
copy_to_standalone "${APPLIANCE_PULL_SECRET_FILE}" "${remote_pull_secret}"

printf -v REMOTE_PULL_SECRET_REMOTE '%q' "${remote_pull_secret}"

run_standalone_root_bash <<REMOTE_SECRET
set -euo pipefail

REMOTE_PULL_SECRET=${REMOTE_PULL_SECRET_REMOTE}

#### These steps install container auth for root podman builds

# The remote temporary file is removed after it is installed.
install -D -m 0600 "\${REMOTE_PULL_SECRET}" /root/.config/containers/auth.json
rm -f "\${REMOTE_PULL_SECRET}"
REMOTE_SECRET

printf -v OCP_VERSION_REMOTE '%q' "${APPLIANCE_OCP_VERSION}"
printf -v OCP_CHANNEL_REMOTE '%q' "${APPLIANCE_OCP_CHANNEL}"
printf -v OCP_ARCH_REMOTE '%q' "${APPLIANCE_OCP_CPU_ARCHITECTURE}"
printf -v IMAGE_DISK_SIZE_REMOTE '%q' "${APPLIANCE_IMAGE_DISK_SIZE_GB}"
printf -v BUILDER_IMAGE_REMOTE '%q' "${APPLIANCE_BUILDER_IMAGE}"
printf -v ASSETS_DIR_REMOTE '%q' "${APPLIANCE_ASSETS_DIR}"
printf -v CORE_PASSWORD_REMOTE '%q' "${APPLIANCE_CORE_PASSWORD}"
printf -v CORE_SSH_KEY_REMOTE '%q' "${APPLIANCE_CORE_SSH_PUBLIC_KEY}"
printf -v OPERATOR_PACKAGES_REMOTE '%q' "${APPLIANCE_OPERATOR_PACKAGES_PAYLOAD}"
printf -v ADDITIONAL_IMAGES_REMOTE '%q' "${APPLIANCE_ADDITIONAL_IMAGES_PAYLOAD}"

run_standalone_root_bash <<REMOTE_SCRIPT
set -euo pipefail

OCP_VERSION=${OCP_VERSION_REMOTE}
OCP_CHANNEL=${OCP_CHANNEL_REMOTE}
OCP_ARCH=${OCP_ARCH_REMOTE}
IMAGE_DISK_SIZE_GB=${IMAGE_DISK_SIZE_REMOTE}
BUILDER_IMAGE=${BUILDER_IMAGE_REMOTE}
ASSETS_DIR=${ASSETS_DIR_REMOTE}
CORE_PASSWORD=${CORE_PASSWORD_REMOTE}
CORE_SSH_KEY=${CORE_SSH_KEY_REMOTE}
OPERATOR_PACKAGES=${OPERATOR_PACKAGES_REMOTE}
ADDITIONAL_IMAGES=${ADDITIONAL_IMAGES_REMOTE}
PULL_SECRET_PATH=/root/.config/containers/auth.json

#### These steps create the standalone appliance asset directories

# Keep build inputs under the configured remote staging tree.
echo "Creating standalone appliance asset directories."
mkdir -p "\${ASSETS_DIR}/openshift"
mkdir -p "\${ASSETS_DIR}/cache"
mkdir -p /srv/appliance/secrets
cp "\${PULL_SECRET_PATH}" /srv/appliance/secrets/pull-secret.txt
chmod 0600 /srv/appliance/secrets/pull-secret.txt

#### These steps write appliance-config.yaml

# The appliance config includes real pull-secret content and is not tracked.
echo "Writing \${ASSETS_DIR}/appliance-config.yaml."
export OCP_VERSION OCP_CHANNEL OCP_ARCH IMAGE_DISK_SIZE_GB BUILDER_IMAGE
export ASSETS_DIR CORE_PASSWORD CORE_SSH_KEY PULL_SECRET_PATH OPERATOR_PACKAGES
export ADDITIONAL_IMAGES
python3 - <<'PY'
import os
from pathlib import Path
from collections import OrderedDict

def squote(value):
    return "'" + value.replace("'", "''") + "'"

pull_secret = Path(os.environ["PULL_SECRET_PATH"]).read_text().strip()
operator_catalogs = OrderedDict()
additional_images = [
    line for line in os.environ["ADDITIONAL_IMAGES"].splitlines() if line.strip()
]

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
]

if additional_images:
    lines.append("additionalImages:")
    for image in additional_images:
        lines.append(f"- name: {squote(image)}")

lines.append("operators:")

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

echo "Standalone appliance assets are ready in \${ASSETS_DIR}."
REMOTE_SCRIPT
