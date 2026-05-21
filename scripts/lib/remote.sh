#!/usr/bin/env bash

#### Shared helpers for running simple commands on the virtualization host

# Source this file from numbered scripts. Do not run it directly.

repo_root() {
    local script_dir

    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "${script_dir}/../.." >/dev/null 2>&1
    pwd
}

load_host_config() {
    local root_dir

    root_dir="$(repo_root)"

    if [[ ! -f "${root_dir}/config/host.env" ]]; then
        echo "Missing config/host.env"
        echo "Copy config/host.env.example to config/host.env and adjust it."
        exit 1
    fi

    # shellcheck disable=SC1091
    source "${root_dir}/config/host.env"
}

load_rhsm_config() {
    local root_dir

    root_dir="$(repo_root)"

    if [[ ! -f "${root_dir}/config/rhsm.env" ]]; then
        echo "Missing config/rhsm.env"
        echo "Copy config/rhsm.env.example to config/rhsm.env and fill in operator-provided values."
        exit 1
    fi

    # shellcheck disable=SC1091
    source "${root_dir}/config/rhsm.env"
}

load_network_config() {
    local root_dir

    root_dir="$(repo_root)"

    if [[ ! -f "${root_dir}/config/network.env" ]]; then
        echo "Missing config/network.env"
        echo "Copy config/network.env.example to config/network.env and fill in operator-provided values."
        exit 1
    fi

    # shellcheck disable=SC1091
    source "${root_dir}/config/network.env"
}

load_foundry_config() {
    local root_dir

    root_dir="$(repo_root)"

    if [[ ! -f "${root_dir}/config/foundry.env" ]]; then
        echo "Missing config/foundry.env"
        echo "Copy config/foundry.env.example to config/foundry.env and adjust it."
        exit 1
    fi

    # shellcheck disable=SC1091
    source "${root_dir}/config/foundry.env"

    APPLIANCE_FOUNDRY_NAME="${APPLIANCE_FOUNDRY_NAME:-foundry}"
    APPLIANCE_FOUNDRY_USER="${APPLIANCE_FOUNDRY_USER:-appliance}"
    APPLIANCE_FOUNDRY_APPLIANCE_IP="${APPLIANCE_FOUNDRY_APPLIANCE_IP:-172.16.10.10}"

    if [[ -z "${APPLIANCE_FOUNDRY_SSH_KEY:-}" ]]; then
        APPLIANCE_FOUNDRY_SSH_KEY="${APPLIANCE_HOST_SSH_KEY:-}"
    fi
}

remote_target() {
    printf '%s@%s\n' "${APPLIANCE_HOST_USER}" "${APPLIANCE_HOST}"
}

run_remote() {
    if [[ -n "${APPLIANCE_HOST_SSH_KEY:-}" ]]; then
        ssh \
            -i "${APPLIANCE_HOST_SSH_KEY}" \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            "$(remote_target)" \
            "$@"
    else
        ssh \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            "$(remote_target)" \
            "$@"
    fi
}

run_remote_bash() {
    if [[ -n "${APPLIANCE_HOST_SSH_KEY:-}" ]]; then
        ssh \
            -i "${APPLIANCE_HOST_SSH_KEY}" \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            "$(remote_target)" \
            /bin/bash -s
    else
        ssh \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            "$(remote_target)" \
            /bin/bash -s
    fi
}

write_foundry_ssh_config() {
    local ssh_config

    ssh_config="$1"

    {
        echo "Host appliance-virt-host"
        echo "  HostName ${APPLIANCE_HOST}"
        echo "  User ${APPLIANCE_HOST_USER}"
        if [[ -n "${APPLIANCE_HOST_SSH_KEY:-}" ]]; then
            echo "  IdentityFile ${APPLIANCE_HOST_SSH_KEY}"
        fi
        echo "  StrictHostKeyChecking no"
        echo "  UserKnownHostsFile /dev/null"
        echo
        echo "Host appliance-foundry"
        echo "  HostName ${APPLIANCE_FOUNDRY_APPLIANCE_IP}"
        echo "  User ${APPLIANCE_FOUNDRY_USER}"
        if [[ -n "${APPLIANCE_FOUNDRY_SSH_KEY:-}" ]]; then
            echo "  IdentityFile ${APPLIANCE_FOUNDRY_SSH_KEY}"
        fi
        echo "  ProxyJump appliance-virt-host"
        echo "  StrictHostKeyChecking no"
        echo "  UserKnownHostsFile /dev/null"
    } > "${ssh_config}"

    chmod 0600 "${ssh_config}"
}

run_foundry() {
    local ssh_config
    local status

    ssh_config="$(mktemp)"
    write_foundry_ssh_config "${ssh_config}"

    ssh -F "${ssh_config}" appliance-foundry "$@" || status="$?"
    status="${status:-0}"

    rm -f "${ssh_config}"
    return "${status}"
}

run_foundry_bash() {
    local ssh_config
    local status

    ssh_config="$(mktemp)"
    write_foundry_ssh_config "${ssh_config}"

    ssh -F "${ssh_config}" appliance-foundry /bin/bash -s || status="$?"
    status="${status:-0}"

    rm -f "${ssh_config}"
    return "${status}"
}
