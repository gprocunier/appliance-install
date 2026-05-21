#!/usr/bin/env bash
set -euo pipefail

#### These steps register the standalone foundry host with Red Hat

# Run this script from the operator workstation, in the repository root.
# This script sends RHSM registration commands to an existing RHEL 10.x host.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/standalone.sh"

load_standalone_config
validate_standalone_config
load_rhsm_config

RHSM_BASEOS_REPO="${RHSM_BASEOS_REPO:-rhel-10-for-x86_64-baseos-rpms}"
RHSM_APPSTREAM_REPO="${RHSM_APPSTREAM_REPO:-rhel-10-for-x86_64-appstream-rpms}"
RHSM_CODEREADY_REPO="${RHSM_CODEREADY_REPO:-codeready-builder-for-rhel-10-x86_64-rpms}"

printf -v RHSM_ORG_ID_REMOTE '%q' "${RHSM_ORG_ID}"
printf -v RHSM_ACTIVATION_KEY_REMOTE '%q' "${RHSM_ACTIVATION_KEY}"
printf -v RHSM_BASEOS_REPO_REMOTE '%q' "${RHSM_BASEOS_REPO}"
printf -v RHSM_APPSTREAM_REPO_REMOTE '%q' "${RHSM_APPSTREAM_REPO}"
printf -v RHSM_CODEREADY_REPO_REMOTE '%q' "${RHSM_CODEREADY_REPO}"

run_standalone_root_bash <<REMOTE_SCRIPT
set -euo pipefail

RHSM_ORG_ID=${RHSM_ORG_ID_REMOTE}
RHSM_ACTIVATION_KEY=${RHSM_ACTIVATION_KEY_REMOTE}
RHSM_BASEOS_REPO=${RHSM_BASEOS_REPO_REMOTE}
RHSM_APPSTREAM_REPO=${RHSM_APPSTREAM_REPO_REMOTE}
RHSM_CODEREADY_REPO=${RHSM_CODEREADY_REPO_REMOTE}

#### These steps make sure subscription-manager controls CDN repositories

# Register the host only when it is not already registered.
if subscription-manager identity >/dev/null 2>&1; then
    echo "Standalone foundry host is already registered with Red Hat."
else
    subscription-manager register \
        --org "\${RHSM_ORG_ID}" \
        --activationkey "\${RHSM_ACTIVATION_KEY}"
fi

# Let subscription-manager manage the enabled repository set.
subscription-manager config --rhsm.manage_repos=1

#### These steps enable repositories needed for appliance image building

# BaseOS and AppStream provide RHEL, container tools, qemu-img, and utilities.
subscription-manager repos --enable "\${RHSM_BASEOS_REPO}"
subscription-manager repos --enable "\${RHSM_APPSTREAM_REPO}"

# CodeReady is useful for optional dependencies and troubleshooting tools.
subscription-manager repos --enable "\${RHSM_CODEREADY_REPO}" || true

# Refresh package metadata after repository changes.
dnf clean all
dnf makecache
REMOTE_SCRIPT
