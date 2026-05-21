#!/usr/bin/env bash

#### Shared helpers for the standalone foundry path

# Source this file from scripts/foundry-standalone/*.sh. Do not run it directly.

STANDALONE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${STANDALONE_LIB_DIR}/../../lib/remote.sh"

load_standalone_config() {
    local root_dir

    root_dir="$(repo_root)"

    if [[ ! -f "${root_dir}/config/foundry-standalone.env" ]]; then
        echo "Missing config/foundry-standalone.env"
        echo "Copy config/foundry-standalone.env.example to config/foundry-standalone.env and adjust it."
        exit 1
    fi

    # shellcheck disable=SC1091
    source "${root_dir}/config/foundry-standalone.env"

    APPLIANCE_STANDALONE_USER="${APPLIANCE_STANDALONE_USER:-root}"
    APPLIANCE_STANDALONE_SSH_KEY="${APPLIANCE_STANDALONE_SSH_KEY:-}"
    APPLIANCE_STANDALONE_CORE_SSH_PUBLIC_KEY_FILE="${APPLIANCE_STANDALONE_CORE_SSH_PUBLIC_KEY_FILE:-${APPLIANCE_STANDALONE_SSH_KEY}.pub}"
    APPLIANCE_STANDALONE_LOCAL_OUTPUT_DIR="${APPLIANCE_STANDALONE_LOCAL_OUTPUT_DIR:-work/foundry-standalone}"

    # config/appliance.env.example references this variable for its default
    # APPLIANCE_CORE_SSH_PUBLIC_KEY_FILE value.
    # shellcheck disable=SC2034
    APPLIANCE_FOUNDRY_SSH_PUBLIC_KEY_FILE="${APPLIANCE_STANDALONE_CORE_SSH_PUBLIC_KEY_FILE}"

    # config/appliance.env.example references this variable for its default
    # APPLIANCE_AGENT_NTP_SOURCE value, even though this standalone path does
    # not generate Agent Installer network config.
    # shellcheck disable=SC2034
    APPLIANCE_FOUNDRY_APPLIANCE_IP="${APPLIANCE_STANDALONE_HOST}"
}

validate_standalone_config() {
    validate_non_empty "APPLIANCE_STANDALONE_HOST" "${APPLIANCE_STANDALONE_HOST:-}"
    validate_linux_user "APPLIANCE_STANDALONE_USER" "${APPLIANCE_STANDALONE_USER}"

    if [[ -n "${APPLIANCE_STANDALONE_SSH_KEY}" && ! -f "${APPLIANCE_STANDALONE_SSH_KEY}" ]]; then
        fail "Missing APPLIANCE_STANDALONE_SSH_KEY: ${APPLIANCE_STANDALONE_SSH_KEY}"
    fi
}

standalone_target() {
    printf '%s@%s\n' "${APPLIANCE_STANDALONE_USER}" "${APPLIANCE_STANDALONE_HOST}"
}

run_standalone() {
    if [[ -n "${APPLIANCE_STANDALONE_SSH_KEY:-}" ]]; then
        ssh \
            -i "${APPLIANCE_STANDALONE_SSH_KEY}" \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            "$(standalone_target)" \
            "$@"
    else
        ssh \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            "$(standalone_target)" \
            "$@"
    fi
}

copy_to_standalone() {
    local source_path
    local destination_path

    source_path="$1"
    destination_path="$2"

    if [[ -n "${APPLIANCE_STANDALONE_SSH_KEY:-}" ]]; then
        scp \
            -i "${APPLIANCE_STANDALONE_SSH_KEY}" \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            "${source_path}" \
            "$(standalone_target):${destination_path}"
    else
        scp \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            "${source_path}" \
            "$(standalone_target):${destination_path}"
    fi
}

run_standalone_bash() {
    run_standalone /bin/bash -s
}

run_standalone_root_bash() {
    if [[ "${APPLIANCE_STANDALONE_USER}" == "root" ]]; then
        run_standalone /bin/bash -s
    else
        run_standalone sudo -n /bin/bash -s
    fi
}
