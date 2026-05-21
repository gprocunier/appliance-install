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

load_appliance_config() {
    local root_dir

    root_dir="$(repo_root)"

    if [[ ! -f "${root_dir}/config/appliance.env" ]]; then
        echo "Missing config/appliance.env"
        echo "Copy config/appliance.env.example to config/appliance.env and adjust it."
        exit 1
    fi

    # shellcheck disable=SC1091
    source "${root_dir}/config/appliance.env"
}

load_operator_config() {
    local root_dir
    local operator_declare

    root_dir="$(repo_root)"

    if [[ -f "${root_dir}/config/operators.env" ]]; then
        # shellcheck disable=SC1091
        source "${root_dir}/config/operators.env"
    elif [[ -f "${root_dir}/config/operators.env.example" ]]; then
        # shellcheck disable=SC1091
        source "${root_dir}/config/operators.env.example"
    else
        echo "Missing config/operators.env"
        echo "Copy config/operators.env.example to config/operators.env and adjust it."
        exit 1
    fi

    APPLIANCE_OPERATOR_CATALOG="${APPLIANCE_OPERATOR_CATALOG:-registry.redhat.io/redhat/redhat-operator-index:v${APPLIANCE_OCP_VERSION:-4.21}}"

    if ! operator_declare="$(declare -p APPLIANCE_OPERATOR_PACKAGES 2>/dev/null)"; then
        fail "APPLIANCE_OPERATOR_PACKAGES must be defined in config/operators.env."
    fi

    if [[ "${operator_declare}" != declare\ -a* && "${operator_declare}" != declare\ -ax* ]]; then
        fail "APPLIANCE_OPERATOR_PACKAGES must be a bash array in config/operators.env."
    fi
}

load_additional_images_config() {
    local root_dir
    local images_declare

    root_dir="$(repo_root)"

    if [[ -f "${root_dir}/config/additional-images.env" ]]; then
        # shellcheck disable=SC1091
        source "${root_dir}/config/additional-images.env"
    elif [[ -f "${root_dir}/config/additional-images.env.example" ]]; then
        # shellcheck disable=SC1091
        source "${root_dir}/config/additional-images.env.example"
    else
        APPLIANCE_ADDITIONAL_IMAGES=()
    fi

    APPLIANCE_ADDITIONAL_IMAGES_FILE="${APPLIANCE_ADDITIONAL_IMAGES_FILE:-}"

    if ! images_declare="$(declare -p APPLIANCE_ADDITIONAL_IMAGES 2>/dev/null)"; then
        APPLIANCE_ADDITIONAL_IMAGES=()
        images_declare="$(declare -p APPLIANCE_ADDITIONAL_IMAGES)"
    fi

    if [[ "${images_declare}" != declare\ -a* && "${images_declare}" != declare\ -ax* ]]; then
        fail "APPLIANCE_ADDITIONAL_IMAGES must be a bash array in config/additional-images.env."
    fi
}

normalize_operator_entry() {
    local entry
    local first
    local second
    local third
    local extra
    local catalog
    local package
    local channel

    entry="$1"

    IFS='|' read -r first second third extra <<< "${entry}"

    if [[ -n "${extra:-}" ]]; then
        fail "Operator entry has too many fields: ${entry}"
    fi

    if [[ -n "${third:-}" ]]; then
        catalog="${first}"
        package="${second}"
        channel="${third}"
    else
        catalog="${APPLIANCE_OPERATOR_CATALOG}"
        package="${first}"
        channel="${second}"
    fi

    validate_non_empty "operator catalog" "${catalog}"
    validate_non_empty "operator package" "${package}"
    validate_non_empty "operator channel" "${channel}"

    if [[ ! "${catalog}" =~ ^[A-Za-z0-9._/:@-]+$ ]]; then
        fail "Operator catalog contains unsupported characters: ${catalog}"
    fi

    if [[ ! "${package}" =~ ^[A-Za-z0-9._-]+$ ]]; then
        fail "Operator package contains unsupported characters: ${package}"
    fi

    if [[ ! "${channel}" =~ ^[A-Za-z0-9._-]+$ ]]; then
        fail "Operator channel contains unsupported characters: ${channel}"
    fi

    printf '%s|%s|%s\n' "${catalog}" "${package}" "${channel}"
}

normalize_additional_image_entry() {
    local image

    image="$1"

    validate_non_empty "additional image" "${image}"

    if [[ "${image}" == *"://"* ]]; then
        fail "Additional image entries must be image references, not URLs: ${image}"
    fi

    if [[ "${image}" =~ [[:space:]\",] ]]; then
        fail "Additional image entries must not contain whitespace, quotes, or commas: ${image}"
    fi

    if [[ ! "${image}" =~ ^[A-Za-z0-9._/:@+-]+$ ]]; then
        fail "Additional image contains unsupported characters: ${image}"
    fi

    printf '%s\n' "${image}"
}

additional_images_payload() {
    local image
    local image_file
    local line
    local root_dir

    for image in "${APPLIANCE_ADDITIONAL_IMAGES[@]}"; do
        normalize_additional_image_entry "${image}"
    done

    if [[ -z "${APPLIANCE_ADDITIONAL_IMAGES_FILE}" ]]; then
        return
    fi

    root_dir="$(repo_root)"

    if [[ "${APPLIANCE_ADDITIONAL_IMAGES_FILE}" == /* ]]; then
        image_file="${APPLIANCE_ADDITIONAL_IMAGES_FILE}"
    else
        image_file="${root_dir}/${APPLIANCE_ADDITIONAL_IMAGES_FILE}"
    fi

    if [[ ! -f "${image_file}" ]]; then
        fail "Missing APPLIANCE_ADDITIONAL_IMAGES_FILE: ${image_file}"
    fi

    while IFS= read -r line || [[ -n "${line}" ]]; do
        if [[ -z "${line//[[:space:]]/}" ]]; then
            continue
        fi

        if [[ "${line}" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        normalize_additional_image_entry "${line}"
    done < "${image_file}"
}

operator_packages_payload() {
    local entry
    local count

    count=0

    for entry in "${APPLIANCE_OPERATOR_PACKAGES[@]}"; do
        normalize_operator_entry "${entry}"
        count=$((count + 1))
    done

    if (( count == 0 )); then
        fail "APPLIANCE_OPERATOR_PACKAGES must contain at least one operator entry."
    fi
}

operator_package_names() {
    local entry
    local normalized
    local package

    for entry in "${APPLIANCE_OPERATOR_PACKAGES[@]}"; do
        normalized="$(normalize_operator_entry "${entry}")"
        package="${normalized#*|}"
        package="${package%%|*}"
        printf '%s\n' "${package}"
    done
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
