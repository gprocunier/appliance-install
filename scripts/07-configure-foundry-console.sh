#!/usr/bin/env bash
set -euo pipefail

#### These steps configure foundry graphical console login

# Run this script from the operator workstation, in the repository root.
# This script reaches foundry through the virtualization host jump path.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/remote.sh"

load_host_config
load_network_config
load_foundry_config

APPLIANCE_FOUNDRY_CONSOLE_PASSWORD="${APPLIANCE_FOUNDRY_CONSOLE_PASSWORD:-}"

#### These steps validate console password settings before making changes

# Keep console login explicit and avoid writing placeholder values to foundry.
validate_linux_user "APPLIANCE_FOUNDRY_USER" "${APPLIANCE_FOUNDRY_USER}"
validate_non_empty "APPLIANCE_FOUNDRY_CONSOLE_PASSWORD" "${APPLIANCE_FOUNDRY_CONSOLE_PASSWORD}"

if [[ "${APPLIANCE_FOUNDRY_CONSOLE_PASSWORD}" == replace-with-* ]]; then
    fail "APPLIANCE_FOUNDRY_CONSOLE_PASSWORD must be changed in config/foundry.env."
fi

if [[ "${APPLIANCE_FOUNDRY_CONSOLE_PASSWORD}" == *$'\n'* ]]; then
    fail "APPLIANCE_FOUNDRY_CONSOLE_PASSWORD must be a single-line value."
fi

printf -v FOUNDRY_USER_REMOTE '%q' "${APPLIANCE_FOUNDRY_USER}"
printf -v FOUNDRY_CONSOLE_PASSWORD_REMOTE '%q' "${APPLIANCE_FOUNDRY_CONSOLE_PASSWORD}"

run_foundry sudo -n /bin/bash -s <<REMOTE_SCRIPT
set -euo pipefail

FOUNDRY_USER=${FOUNDRY_USER_REMOTE}
FOUNDRY_CONSOLE_PASSWORD=${FOUNDRY_CONSOLE_PASSWORD_REMOTE}

#### These steps apply local console credentials

# Convert the readable config password to a local SHA-512 password hash.
if ! command -v openssl >/dev/null 2>&1; then
    echo "Missing openssl on foundry." >&2
    exit 1
fi

FOUNDRY_CONSOLE_PASSWORD_HASH="\$(printf '%s\n' "\${FOUNDRY_CONSOLE_PASSWORD}" | openssl passwd -6 -stdin)"

# Set the console password on the appliance sudo user.
if ! id "\${FOUNDRY_USER}" >/dev/null 2>&1; then
    echo "Missing foundry user: \${FOUNDRY_USER}" >&2
    exit 1
fi

usermod --password "\${FOUNDRY_CONSOLE_PASSWORD_HASH}" "\${FOUNDRY_USER}"

# Set the same console password on the RHEL cloud-image default user when present.
if id cloud-user >/dev/null 2>&1; then
    usermod --password "\${FOUNDRY_CONSOLE_PASSWORD_HASH}" cloud-user
else
    echo "cloud-user does not exist on this image; skipping cloud-user password."
fi

#### These steps keep appliance sudo passwordless

# Passwordless sudo keeps the lab operator account useful from console and SSH.
cat > /etc/sudoers.d/90-appliance <<SUDOERS
\${FOUNDRY_USER} ALL=(ALL) NOPASSWD:ALL
SUDOERS
chmod 0440 /etc/sudoers.d/90-appliance
visudo -cf /etc/sudoers.d/90-appliance >/dev/null

#### These steps show account lock state without printing secrets

passwd -S "\${FOUNDRY_USER}"
if id cloud-user >/dev/null 2>&1; then
    passwd -S cloud-user
fi
REMOTE_SCRIPT
