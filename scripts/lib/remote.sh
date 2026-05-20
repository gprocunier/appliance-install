#!/usr/bin/env bash

#### Shared helpers for running simple commands on the virtualization host

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
