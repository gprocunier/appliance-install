#!/usr/bin/env bash

#### Shared helpers for running simple commands on the virtualization host

# Source this file from numbered scripts. Do not run it directly.

repo_root() {
    local script_dir

    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "${script_dir}/../.." >/dev/null 2>&1 || exit 1
    pwd
}

fail() {
    echo "$1" >&2
    exit 1
}

validate_non_empty() {
    local label
    local value

    label="$1"
    value="$2"

    if [[ -z "${value}" ]]; then
        fail "${label} must not be empty."
    fi
}

validate_positive_integer() {
    local label
    local value

    label="$1"
    value="$2"

    if [[ ! "${value}" =~ ^[0-9]+$ ]] || [[ "${value}" == "0" ]]; then
        fail "${label} must be a positive integer."
    fi
}

validate_boolean() {
    local label
    local value

    label="$1"
    value="$2"

    if [[ "${value}" != "true" && "${value}" != "false" ]]; then
        fail "${label} must be true or false."
    fi
}

validate_simple_name() {
    local label
    local value

    label="$1"
    value="$2"

    validate_non_empty "${label}" "${value}"

    if [[ "${#value}" -gt 63 ]]; then
        fail "${label} must be 63 characters or fewer."
    fi

    if [[ ! "${value}" =~ ^[A-Za-z0-9._-]+$ ]]; then
        fail "${label} must contain only letters, numbers, dots, underscores, and hyphens."
    fi
}

validate_dns_label() {
    local label
    local value

    label="$1"
    value="$2"

    validate_non_empty "${label}" "${value}"

    if [[ "${#value}" -gt 63 ]]; then
        fail "${label} must be 63 characters or fewer."
    fi

    if [[ ! "${value}" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]]; then
        fail "${label} must be a valid DNS label."
    fi
}

validate_fqdn() {
    local label
    local value
    local part
    local -a parts

    label="$1"
    value="$2"

    validate_non_empty "${label}" "${value}"

    if [[ "${#value}" -gt 253 ]]; then
        fail "${label} must be 253 characters or fewer."
    fi

    if [[ "${value}" == .* || "${value}" == *..* || "${value}" == *. ]]; then
        fail "${label} must not contain empty DNS labels."
    fi

    IFS=. read -r -a parts <<< "${value}"
    for part in "${parts[@]}"; do
        validate_dns_label "${label}" "${part}"
    done
}

validate_linux_user() {
    local label
    local value

    label="$1"
    value="$2"

    validate_non_empty "${label}" "${value}"

    if [[ "${#value}" -gt 32 ]]; then
        fail "${label} must be 32 characters or fewer."
    fi

    if [[ ! "${value}" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
        fail "${label} must be a valid Linux user name."
    fi
}

validate_absolute_path() {
    local label
    local value

    label="$1"
    value="$2"

    validate_non_empty "${label}" "${value}"

    if [[ "${value}" != /* ]]; then
        fail "${label} must be an absolute path."
    fi

    if [[ "${value}" =~ [[:space:]\",] ]]; then
        fail "${label} must not contain whitespace, quotes, or commas."
    fi
}

validate_ipv4() {
    local label
    local value
    local octet
    local octets

    label="$1"
    value="$2"

    if [[ ! "${value}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        fail "${label} must be an IPv4 address."
    fi

    IFS=. read -r -a octets <<< "${value}"
    for octet in "${octets[@]}"; do
        if (( 10#${octet} > 255 )); then
            fail "${label} has an IPv4 octet greater than 255."
        fi
    done
}

validate_ipv4_prefix() {
    local label
    local value

    label="$1"
    value="$2"

    if [[ ! "${value}" =~ ^[0-9]+$ ]] || (( 10#${value} < 1 || 10#${value} > 32 )); then
        fail "${label} must be an IPv4 prefix length from 1 to 32."
    fi
}

validate_ipv4_cidr() {
    local label
    local value
    local ip
    local prefix

    label="$1"
    value="$2"

    if [[ ! "${value}" =~ ^([^/]+)/([0-9]+)$ ]]; then
        fail "${label} must be an IPv4 CIDR such as 172.16.10.0/24."
    fi

    ip="${BASH_REMATCH[1]}"
    prefix="${BASH_REMATCH[2]}"

    validate_ipv4 "${label}" "${ip}"
    validate_ipv4_prefix "${label}" "${prefix}"
}

validate_mac() {
    local label
    local value

    label="$1"
    value="$2"

    if [[ ! "${value}" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]]; then
        fail "${label} must be a MAC address such as 52:54:00:10:10:10."
    fi
}

validate_ssh_public_key() {
    local label
    local value

    label="$1"
    value="$2"

    if [[ ! "${value}" =~ ^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp[0-9]+|sk-ssh-ed25519@openssh.com|sk-ecdsa-sha2-nistp256@openssh.com)[[:space:]][A-Za-z0-9+/=]+([[:space:]].*)?$ ]]; then
        fail "${label} must contain one OpenSSH public key."
    fi
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

write_identity_file_line() {
    local key_path

    key_path="$1"
    key_path="${key_path//\"/\\\"}"

    printf '  IdentityFile "%s"\n' "${key_path}"
}

write_foundry_ssh_config() {
    local ssh_config

    ssh_config="$1"

    {
        echo "Host appliance-virt-host"
        echo "  HostName ${APPLIANCE_HOST}"
        echo "  User ${APPLIANCE_HOST_USER}"
        if [[ -n "${APPLIANCE_HOST_SSH_KEY:-}" ]]; then
            write_identity_file_line "${APPLIANCE_HOST_SSH_KEY}"
        fi
        echo "  StrictHostKeyChecking no"
        echo "  UserKnownHostsFile /dev/null"
        echo
        echo "Host appliance-foundry"
        echo "  HostName ${APPLIANCE_FOUNDRY_APPLIANCE_IP}"
        echo "  User ${APPLIANCE_FOUNDRY_USER}"
        if [[ -n "${APPLIANCE_FOUNDRY_SSH_KEY:-}" ]]; then
            write_identity_file_line "${APPLIANCE_FOUNDRY_SSH_KEY}"
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
