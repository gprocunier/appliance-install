#!/usr/bin/env bash
set -euo pipefail

#### These steps register the virtualization host with Red Hat

# Run this script from the operator workstation, in the repository root.
# This script sends RHSM registration commands to the virtualization host over SSH.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/remote.sh"

load_host_config
load_rhsm_config

RHSM_BASEOS_REPO="${RHSM_BASEOS_REPO:-rhel-10-for-x86_64-baseos-rpms}"
RHSM_APPSTREAM_REPO="${RHSM_APPSTREAM_REPO:-rhel-10-for-x86_64-appstream-rpms}"
RHSM_FAST_DATAPATH_REPO="${RHSM_FAST_DATAPATH_REPO:-fast-datapath-for-rhel-10-x86_64-rpms}"
RHSM_CODEREADY_REPO="${RHSM_CODEREADY_REPO:-codeready-builder-for-rhel-10-x86_64-rpms}"

printf -v RHSM_ORG_ID_REMOTE '%q' "${RHSM_ORG_ID}"
printf -v RHSM_ACTIVATION_KEY_REMOTE '%q' "${RHSM_ACTIVATION_KEY}"
printf -v RHSM_BASEOS_REPO_REMOTE '%q' "${RHSM_BASEOS_REPO}"
printf -v RHSM_APPSTREAM_REPO_REMOTE '%q' "${RHSM_APPSTREAM_REPO}"
printf -v RHSM_FAST_DATAPATH_REPO_REMOTE '%q' "${RHSM_FAST_DATAPATH_REPO}"
printf -v RHSM_CODEREADY_REPO_REMOTE '%q' "${RHSM_CODEREADY_REPO}"

run_remote_bash <<REMOTE_SCRIPT
set -euo pipefail

RHSM_ORG_ID=${RHSM_ORG_ID_REMOTE}
RHSM_ACTIVATION_KEY=${RHSM_ACTIVATION_KEY_REMOTE}
RHSM_BASEOS_REPO=${RHSM_BASEOS_REPO_REMOTE}
RHSM_APPSTREAM_REPO=${RHSM_APPSTREAM_REPO_REMOTE}
RHSM_FAST_DATAPATH_REPO=${RHSM_FAST_DATAPATH_REPO_REMOTE}
RHSM_CODEREADY_REPO=${RHSM_CODEREADY_REPO_REMOTE}

#### These steps make sure subscription-manager controls CDN repositories

# Register the host only when it is not already registered.
if subscription-manager identity >/dev/null 2>&1; then
    echo "Host is already registered with Red Hat."
else
    subscription-manager register \
        --org "\${RHSM_ORG_ID}" \
        --activationkey "\${RHSM_ACTIVATION_KEY}"
fi

# Let subscription-manager manage the enabled repository set.
subscription-manager config --rhsm.manage_repos=1

#### These steps enable the repositories needed for the virtualization host

# BaseOS and AppStream provide the base RHEL and virtualization packages.
subscription-manager repos --enable "\${RHSM_BASEOS_REPO}"
subscription-manager repos --enable "\${RHSM_APPSTREAM_REPO}"

# Fast Datapath provides the Open vSwitch package used by the appliance lab.
subscription-manager repos --enable "\${RHSM_FAST_DATAPATH_REPO}"

# CodeReady is useful for optional dependencies and troubleshooting tools.
subscription-manager repos --enable "\${RHSM_CODEREADY_REPO}" || true

# Refresh package metadata after repository changes.
dnf clean all
dnf makecache
REMOTE_SCRIPT
