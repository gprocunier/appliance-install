#!/usr/bin/env bash
set -euo pipefail

#### These steps configure foundry DNS, NTP, and staging services

# Run this script from the operator workstation, in the repository root.
# This script reaches foundry through the virtualization host jump path.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/remote.sh"

load_host_config
load_network_config
load_foundry_config
load_rhsm_config

APPLIANCE_CLUSTER_DOMAIN="${APPLIANCE_CLUSTER_DOMAIN:-appliance.workshop.lan}"
APPLIANCE_IDM_REALM="${APPLIANCE_IDM_REALM:-${APPLIANCE_CLUSTER_DOMAIN^^}}"
APPLIANCE_IDM_DIRECTORY_MANAGER_PASSWORD="${APPLIANCE_IDM_DIRECTORY_MANAGER_PASSWORD:-}"
APPLIANCE_IDM_ADMIN_PASSWORD="${APPLIANCE_IDM_ADMIN_PASSWORD:-}"
APPLIANCE_IDM_DNS_FORWARDERS="${APPLIANCE_IDM_DNS_FORWARDERS:-192.168.122.1}"
APPLIANCE_MIRROR_REGISTRY_NAME="${APPLIANCE_MIRROR_REGISTRY_NAME:-mirror-registry}"
APPLIANCE_API_IP="${APPLIANCE_API_IP:-172.16.10.5}"
APPLIANCE_INGRESS_IP="${APPLIANCE_INGRESS_IP:-172.16.10.7}"
APPLIANCE_NODE_1_NAME="${APPLIANCE_NODE_1_NAME:-ocp-01}"
APPLIANCE_NODE_1_IP="${APPLIANCE_NODE_1_IP:-172.16.10.11}"
APPLIANCE_NODE_2_NAME="${APPLIANCE_NODE_2_NAME:-ocp-02}"
APPLIANCE_NODE_2_IP="${APPLIANCE_NODE_2_IP:-172.16.10.12}"
APPLIANCE_NODE_3_NAME="${APPLIANCE_NODE_3_NAME:-ocp-03}"
APPLIANCE_NODE_3_IP="${APPLIANCE_NODE_3_IP:-172.16.10.13}"
APPLIANCE_FOUNDRY_HOSTNAME="${APPLIANCE_FOUNDRY_HOSTNAME:-foundry.${APPLIANCE_CLUSTER_DOMAIN}}"
APPLIANCE_FOUNDRY_APPLIANCE_CIDR="${APPLIANCE_FOUNDRY_APPLIANCE_CIDR:-172.16.10.0/24}"
APPLIANCE_FOUNDRY_ASSETS_DIR="${APPLIANCE_FOUNDRY_ASSETS_DIR:-/srv/appliance/assets}"
APPLIANCE_FOUNDRY_HTTP_ROOT="${APPLIANCE_FOUNDRY_HTTP_ROOT:-/srv/appliance}"
APPLIANCE_FOUNDRY_CONSOLE_PASSWORD="${APPLIANCE_FOUNDRY_CONSOLE_PASSWORD:-}"
APPLIANCE_BUILDER_IMAGE="${APPLIANCE_BUILDER_IMAGE:-catalog.redhat.com/software/containers/assisted/agentpreinstall-image-builder-rhel9/65a55174031d94dbea7f2e00}"

#### These steps validate foundry service settings before making changes

# Keep DNS, NTP, and filesystem values inside the formats their services accept.
validate_non_empty "RHSM_ORG_ID" "${RHSM_ORG_ID}"
validate_non_empty "RHSM_ACTIVATION_KEY" "${RHSM_ACTIVATION_KEY}"
validate_fqdn "APPLIANCE_CLUSTER_DOMAIN" "${APPLIANCE_CLUSTER_DOMAIN}"
validate_fqdn "APPLIANCE_IDM_REALM" "${APPLIANCE_IDM_REALM}"
validate_non_empty "APPLIANCE_IDM_DIRECTORY_MANAGER_PASSWORD" "${APPLIANCE_IDM_DIRECTORY_MANAGER_PASSWORD}"
validate_non_empty "APPLIANCE_IDM_ADMIN_PASSWORD" "${APPLIANCE_IDM_ADMIN_PASSWORD}"
validate_non_empty "APPLIANCE_IDM_DNS_FORWARDERS" "${APPLIANCE_IDM_DNS_FORWARDERS}"
validate_linux_user "APPLIANCE_FOUNDRY_USER" "${APPLIANCE_FOUNDRY_USER}"
validate_dns_label "APPLIANCE_MIRROR_REGISTRY_NAME" "${APPLIANCE_MIRROR_REGISTRY_NAME}"
validate_fqdn "APPLIANCE_FOUNDRY_HOSTNAME" "${APPLIANCE_FOUNDRY_HOSTNAME}"
validate_ipv4 "APPLIANCE_FOUNDRY_APPLIANCE_IP" "${APPLIANCE_FOUNDRY_APPLIANCE_IP}"
validate_ipv4_cidr "APPLIANCE_FOUNDRY_APPLIANCE_CIDR" "${APPLIANCE_FOUNDRY_APPLIANCE_CIDR}"
validate_ipv4 "APPLIANCE_API_IP" "${APPLIANCE_API_IP}"
validate_ipv4 "APPLIANCE_INGRESS_IP" "${APPLIANCE_INGRESS_IP}"
validate_dns_label "APPLIANCE_NODE_1_NAME" "${APPLIANCE_NODE_1_NAME}"
validate_ipv4 "APPLIANCE_NODE_1_IP" "${APPLIANCE_NODE_1_IP}"
validate_dns_label "APPLIANCE_NODE_2_NAME" "${APPLIANCE_NODE_2_NAME}"
validate_ipv4 "APPLIANCE_NODE_2_IP" "${APPLIANCE_NODE_2_IP}"
validate_dns_label "APPLIANCE_NODE_3_NAME" "${APPLIANCE_NODE_3_NAME}"
validate_ipv4 "APPLIANCE_NODE_3_IP" "${APPLIANCE_NODE_3_IP}"
validate_absolute_path "APPLIANCE_FOUNDRY_ASSETS_DIR" "${APPLIANCE_FOUNDRY_ASSETS_DIR}"
validate_absolute_path "APPLIANCE_FOUNDRY_HTTP_ROOT" "${APPLIANCE_FOUNDRY_HTTP_ROOT}"
validate_non_empty "APPLIANCE_BUILDER_IMAGE" "${APPLIANCE_BUILDER_IMAGE}"

if [[ "${APPLIANCE_BUILDER_IMAGE}" =~ [[:space:]] ]]; then
    fail "APPLIANCE_BUILDER_IMAGE must not contain whitespace."
fi

if [[ "${APPLIANCE_IDM_REALM}" != "${APPLIANCE_IDM_REALM^^}" ]]; then
    fail "APPLIANCE_IDM_REALM should be uppercase, for example APPLIANCE.WORKSHOP.LAN."
fi

if [[ "${APPLIANCE_IDM_DIRECTORY_MANAGER_PASSWORD}" == replace-with-* ]]; then
    fail "APPLIANCE_IDM_DIRECTORY_MANAGER_PASSWORD must be changed in config/foundry.env."
fi

if [[ "${APPLIANCE_IDM_DIRECTORY_MANAGER_PASSWORD}" == *$'\n'* ]]; then
    fail "APPLIANCE_IDM_DIRECTORY_MANAGER_PASSWORD must be a single-line value."
fi

if [[ "${#APPLIANCE_IDM_DIRECTORY_MANAGER_PASSWORD}" -lt 8 ]]; then
    fail "APPLIANCE_IDM_DIRECTORY_MANAGER_PASSWORD must be at least 8 characters for ipa-server-install."
fi

if [[ "${APPLIANCE_IDM_ADMIN_PASSWORD}" == replace-with-* ]]; then
    fail "APPLIANCE_IDM_ADMIN_PASSWORD must be changed in config/foundry.env."
fi

if [[ "${APPLIANCE_IDM_ADMIN_PASSWORD}" == *$'\n'* ]]; then
    fail "APPLIANCE_IDM_ADMIN_PASSWORD must be a single-line value."
fi

if [[ "${#APPLIANCE_IDM_ADMIN_PASSWORD}" -lt 8 ]]; then
    fail "APPLIANCE_IDM_ADMIN_PASSWORD must be at least 8 characters for ipa-server-install."
fi

read -r -a idm_dns_forwarders <<< "${APPLIANCE_IDM_DNS_FORWARDERS}"
for idm_dns_forwarder in "${idm_dns_forwarders[@]}"; do
    validate_ipv4 "APPLIANCE_IDM_DNS_FORWARDERS" "${idm_dns_forwarder}"
done

if [[ -z "${APPLIANCE_FOUNDRY_CONSOLE_PASSWORD}" ]]; then
    fail "APPLIANCE_FOUNDRY_CONSOLE_PASSWORD must be set in config/foundry.env."
fi

if [[ "${APPLIANCE_FOUNDRY_CONSOLE_PASSWORD}" == replace-with-* ]]; then
    fail "APPLIANCE_FOUNDRY_CONSOLE_PASSWORD must be changed in config/foundry.env."
fi

if [[ "${APPLIANCE_FOUNDRY_CONSOLE_PASSWORD}" == *$'\n'* ]]; then
    fail "APPLIANCE_FOUNDRY_CONSOLE_PASSWORD must be a single-line value."
fi

if [[ -n "${RHSM_BASEOS_REPO:-}" ]]; then
    validate_simple_name "RHSM_BASEOS_REPO" "${RHSM_BASEOS_REPO}"
fi

if [[ -n "${RHSM_APPSTREAM_REPO:-}" ]]; then
    validate_simple_name "RHSM_APPSTREAM_REPO" "${RHSM_APPSTREAM_REPO}"
fi

if [[ -n "${RHSM_CODEREADY_REPO:-}" ]]; then
    validate_simple_name "RHSM_CODEREADY_REPO" "${RHSM_CODEREADY_REPO}"
fi

printf -v RHSM_ORG_ID_REMOTE '%q' "${RHSM_ORG_ID}"
printf -v RHSM_ACTIVATION_KEY_REMOTE '%q' "${RHSM_ACTIVATION_KEY}"
printf -v RHSM_BASEOS_REPO_REMOTE '%q' "${RHSM_BASEOS_REPO:-}"
printf -v RHSM_APPSTREAM_REPO_REMOTE '%q' "${RHSM_APPSTREAM_REPO:-}"
printf -v RHSM_CODEREADY_REPO_REMOTE '%q' "${RHSM_CODEREADY_REPO:-}"
printf -v IDM_REALM_REMOTE '%q' "${APPLIANCE_IDM_REALM}"
printf -v IDM_DIRECTORY_MANAGER_PASSWORD_REMOTE '%q' "${APPLIANCE_IDM_DIRECTORY_MANAGER_PASSWORD}"
printf -v IDM_ADMIN_PASSWORD_REMOTE '%q' "${APPLIANCE_IDM_ADMIN_PASSWORD}"
printf -v IDM_DNS_FORWARDERS_REMOTE '%q' "${APPLIANCE_IDM_DNS_FORWARDERS}"
printf -v FOUNDRY_HOSTNAME_REMOTE '%q' "${APPLIANCE_FOUNDRY_HOSTNAME}"
printf -v FOUNDRY_USER_REMOTE '%q' "${APPLIANCE_FOUNDRY_USER}"
printf -v FOUNDRY_IP_REMOTE '%q' "${APPLIANCE_FOUNDRY_APPLIANCE_IP}"
printf -v FOUNDRY_CIDR_REMOTE '%q' "${APPLIANCE_FOUNDRY_APPLIANCE_CIDR}"
printf -v FOUNDRY_CONSOLE_PASSWORD_REMOTE '%q' "${APPLIANCE_FOUNDRY_CONSOLE_PASSWORD}"
printf -v CLUSTER_DOMAIN_REMOTE '%q' "${APPLIANCE_CLUSTER_DOMAIN}"
printf -v MIRROR_REGISTRY_NAME_REMOTE '%q' "${APPLIANCE_MIRROR_REGISTRY_NAME}"
printf -v API_IP_REMOTE '%q' "${APPLIANCE_API_IP}"
printf -v INGRESS_IP_REMOTE '%q' "${APPLIANCE_INGRESS_IP}"
printf -v NODE_1_NAME_REMOTE '%q' "${APPLIANCE_NODE_1_NAME}"
printf -v NODE_1_IP_REMOTE '%q' "${APPLIANCE_NODE_1_IP}"
printf -v NODE_2_NAME_REMOTE '%q' "${APPLIANCE_NODE_2_NAME}"
printf -v NODE_2_IP_REMOTE '%q' "${APPLIANCE_NODE_2_IP}"
printf -v NODE_3_NAME_REMOTE '%q' "${APPLIANCE_NODE_3_NAME}"
printf -v NODE_3_IP_REMOTE '%q' "${APPLIANCE_NODE_3_IP}"
printf -v ASSETS_DIR_REMOTE '%q' "${APPLIANCE_FOUNDRY_ASSETS_DIR}"
printf -v HTTP_ROOT_REMOTE '%q' "${APPLIANCE_FOUNDRY_HTTP_ROOT}"
printf -v BUILDER_IMAGE_REMOTE '%q' "${APPLIANCE_BUILDER_IMAGE}"

run_foundry sudo -n /bin/bash -s <<REMOTE_SCRIPT
set -euo pipefail

RHSM_ORG_ID=${RHSM_ORG_ID_REMOTE}
RHSM_ACTIVATION_KEY=${RHSM_ACTIVATION_KEY_REMOTE}
RHSM_BASEOS_REPO=${RHSM_BASEOS_REPO_REMOTE}
RHSM_APPSTREAM_REPO=${RHSM_APPSTREAM_REPO_REMOTE}
RHSM_CODEREADY_REPO=${RHSM_CODEREADY_REPO_REMOTE}
IDM_REALM=${IDM_REALM_REMOTE}
IDM_DIRECTORY_MANAGER_PASSWORD=${IDM_DIRECTORY_MANAGER_PASSWORD_REMOTE}
IDM_ADMIN_PASSWORD=${IDM_ADMIN_PASSWORD_REMOTE}
IDM_DNS_FORWARDERS=${IDM_DNS_FORWARDERS_REMOTE}
FOUNDRY_HOSTNAME=${FOUNDRY_HOSTNAME_REMOTE}
FOUNDRY_USER=${FOUNDRY_USER_REMOTE}
FOUNDRY_IP=${FOUNDRY_IP_REMOTE}
FOUNDRY_CIDR=${FOUNDRY_CIDR_REMOTE}
FOUNDRY_CONSOLE_PASSWORD=${FOUNDRY_CONSOLE_PASSWORD_REMOTE}
CLUSTER_DOMAIN=${CLUSTER_DOMAIN_REMOTE}
MIRROR_REGISTRY_NAME=${MIRROR_REGISTRY_NAME_REMOTE}
API_IP=${API_IP_REMOTE}
INGRESS_IP=${INGRESS_IP_REMOTE}
NODE_1_NAME=${NODE_1_NAME_REMOTE}
NODE_1_IP=${NODE_1_IP_REMOTE}
NODE_2_NAME=${NODE_2_NAME_REMOTE}
NODE_2_IP=${NODE_2_IP_REMOTE}
NODE_3_NAME=${NODE_3_NAME_REMOTE}
NODE_3_IP=${NODE_3_IP_REMOTE}
ASSETS_DIR=${ASSETS_DIR_REMOTE}
HTTP_ROOT=${HTTP_ROOT_REMOTE}
BUILDER_IMAGE=${BUILDER_IMAGE_REMOTE}

#### These steps enable foundry graphical console login

# Convert the readable config password to a local SHA-512 password hash.
if ! command -v openssl >/dev/null 2>&1; then
    echo "Missing openssl on foundry." >&2
    exit 1
fi

FOUNDRY_CONSOLE_PASSWORD_HASH="\$(printf '%s\n' "\${FOUNDRY_CONSOLE_PASSWORD}" | openssl passwd -6 -stdin)"

# Set the console password on both local accounts used by the RHEL cloud image.
if ! id "\${FOUNDRY_USER}" >/dev/null 2>&1; then
    echo "Missing foundry user: \${FOUNDRY_USER}" >&2
    exit 1
fi

usermod --password "\${FOUNDRY_CONSOLE_PASSWORD_HASH}" "\${FOUNDRY_USER}"

if id cloud-user >/dev/null 2>&1; then
    usermod --password "\${FOUNDRY_CONSOLE_PASSWORD_HASH}" cloud-user
else
    echo "cloud-user does not exist on this image; skipping cloud-user password."
fi

# Keep the appliance account passwordless for sudo.
cat > /etc/sudoers.d/90-appliance <<SUDOERS
\${FOUNDRY_USER} ALL=(ALL) NOPASSWD:ALL
SUDOERS
chmod 0440 /etc/sudoers.d/90-appliance
visudo -cf /etc/sudoers.d/90-appliance >/dev/null

#### These steps register foundry and install service packages

required_packages=(
    bind-utils
    chrony
    curl
    firewalld
    httpd
    ipa-server
    ipa-server-dns
    jq
    nmstate
    podman
    qemu-img
    skopeo
    tar
    gzip
)

all_required_packages_installed() {
    local package_name

    for package_name in "\${required_packages[@]}"; do
        if ! rpm -q "\${package_name}" >/dev/null 2>&1; then
            return 1
        fi
    done
}

confirm_rhsm_reachable() {
    # Confirm foundry can resolve RHSM before invoking subscription-manager or dnf.
    if ! getent hosts subscription.rhsm.redhat.com >/dev/null; then
        echo "Foundry cannot resolve subscription.rhsm.redhat.com." >&2
        echo "Check foundry upstream DNS before rerunning this script." >&2
        exit 1
    fi

    # Confirm foundry can reach RHSM over HTTPS before waiting on a failing client.
    if ! timeout 10 bash -c '</dev/tcp/subscription.rhsm.redhat.com/443' >/dev/null 2>&1; then
        echo "Foundry cannot connect to subscription.rhsm.redhat.com:443." >&2
        echo "Check the foundry upstream network and host IPv4 forwarding." >&2
        exit 1
    fi
}

foundry_is_registered() {
    [[ -s /etc/pki/consumer/cert.pem && -s /etc/pki/consumer/key.pem ]]
}

# Register foundry only when it is not already registered.
if foundry_is_registered; then
    echo "Foundry is already registered with Red Hat."
else
    confirm_rhsm_reachable
    subscription-manager register --org="\${RHSM_ORG_ID}" --activationkey="\${RHSM_ACTIVATION_KEY}"
fi

#### These steps install DNS, NTP, web, and image-prep tooling

# Install foundry packages only when a required package is missing.
if all_required_packages_installed; then
    echo "Foundry service packages are already installed."
else
    confirm_rhsm_reachable

    # Enable the base RHEL repositories used by foundry services.
    if [[ -n "\${RHSM_BASEOS_REPO}" ]]; then
        subscription-manager repos --enable="\${RHSM_BASEOS_REPO}"
    fi

    if [[ -n "\${RHSM_APPSTREAM_REPO}" ]]; then
        subscription-manager repos --enable="\${RHSM_APPSTREAM_REPO}"
    fi

    if [[ -n "\${RHSM_CODEREADY_REPO}" ]]; then
        subscription-manager repos --enable="\${RHSM_CODEREADY_REPO}" || true
    fi

    echo "Installing foundry service packages. This can take several minutes."
    dnf install -y "\${required_packages[@]}"
fi

#### These steps prepare foundry content directories

# Keep staged appliance content under one predictable tree.
mkdir -p "\${HTTP_ROOT}/assets"
mkdir -p "\${HTTP_ROOT}/images"
mkdir -p "\${HTTP_ROOT}/iso"
mkdir -p "\${HTTP_ROOT}/mirror"
mkdir -p "\${HTTP_ROOT}/registry"
mkdir -p "\${HTTP_ROOT}/openshift"
mkdir -p "\${HTTP_ROOT}/bin"
mkdir -p "\${ASSETS_DIR}/openshift"

cat > "\${HTTP_ROOT}/README.txt" <<README_TEXT
This tree is managed by appliance-install foundry setup.

assets/     OpenShift appliance-builder assets
images/     Appliance and VM images staged for demos
iso/        Generated deployment or config ISO content
mirror/     Mirrored release and operator content
registry/   Local registry storage or exports
openshift/  OpenShift manifests and CRs for appliance builds
bin/        Downloaded client tools such as oc and openshift-install
README_TEXT

# Allow httpd to serve staged content under /srv on SELinux systems.
chcon -R -t httpd_sys_content_t "\${HTTP_ROOT}" >/dev/null 2>&1 || true

#### These steps configure IdM as private DNS for the appliance network

# IdM installation expects the foundry hostname to resolve to the foundry IP.
hostnamectl set-hostname "\${FOUNDRY_HOSTNAME}"
hosts_tmp="\$(mktemp)"
awk -v host="\${FOUNDRY_HOSTNAME}" 'index(\$0, host) == 0 { print }' /etc/hosts > "\${hosts_tmp}"
cat "\${hosts_tmp}" > /etc/hosts
rm -f "\${hosts_tmp}"
printf '%s %s %s\n' "\${FOUNDRY_IP}" "\${FOUNDRY_HOSTNAME}" "\${FOUNDRY_HOSTNAME%%.*}" >> /etc/hosts

# Install IdM with integrated DNS once; later runs manage records through ipa.
read -r -a idm_dns_forwarders <<< "\${IDM_DNS_FORWARDERS}"
ipa_install_forwarder_args=()
for idm_dns_forwarder in "\${idm_dns_forwarders[@]}"; do
    ipa_install_forwarder_args+=(--forwarder "\${idm_dns_forwarder}")
done

if [[ -f /etc/ipa/default.conf ]]; then
    echo "IdM is already installed on foundry."
else
    echo "Installing IdM with integrated DNS. Certificate server setup can be quiet for several minutes."
    ipa-server-install \
        --unattended \
        --setup-dns \
        "\${ipa_install_forwarder_args[@]}" \
        --forward-policy only \
        --no-dnssec-validation \
        --auto-reverse \
        --domain "\${CLUSTER_DOMAIN}" \
        --realm "\${IDM_REALM}" \
        --hostname "\${FOUNDRY_HOSTNAME}" \
        --ip-address "\${FOUNDRY_IP}" \
        --ds-password "\${IDM_DIRECTORY_MANAGER_PASSWORD}" \
        --admin-password "\${IDM_ADMIN_PASSWORD}"
fi

# Authenticate to IdM so DNS records can be managed with ipa commands.
if ! printf '%s\n' "\${IDM_ADMIN_PASSWORD}" | kinit admin >/dev/null 2>&1; then
    echo "Unable to authenticate to IdM as admin." >&2
    exit 1
fi

configure_idm_dns_forwarders() {
    local command_output
    local forwarder
    local -a dnsconfig_args

    dnsconfig_args=(--forward-policy=only)

    for forwarder in "\${idm_dns_forwarders[@]}"; do
        dnsconfig_args+=(--forwarder "\${forwarder}")
    done

    if command_output="\$(ipa dnsconfig-mod "\${dnsconfig_args[@]}" 2>&1)"; then
        echo "Configured IdM global DNS forwarders for foundry."
    elif grep -Fq "no modifications to be performed" <<< "\${command_output}"; then
        echo "IdM global DNS forwarders are already configured."
    else
        printf '%s\n' "\${command_output}" >&2
        exit 1
    fi
}

configure_named_recursion_policy() {
    cat > /etc/named/ipa-options-ext.conf <<NAMED_OPTIONS
/* Managed by appliance-install.
 *
 * Foundry may use IdM/BIND for upstream CDN and mirroring lookups through
 * localhost. Appliance-network clients can query authoritative lab records,
 * but they cannot use foundry as a general recursive internet resolver.
 */

listen-on-v6 { any; };
dnssec-validation no;
recursion yes;
allow-recursion { localhost; };
allow-query-cache { localhost; };
NAMED_OPTIONS

    named-checkconf /etc/named.conf
    systemctl restart named.service
}

#### These steps allow foundry-only upstream DNS recursion

# Foundry needs CDN DNS while mirroring; appliance clients should not recurse.
configure_idm_dns_forwarders
configure_named_recursion_policy

echo "Configuring appliance DNS records in IdM."

ensure_a_record() {
    local record_name
    local record_ip
    local record_output
    local record_line
    local record_has_ip

    record_name="\$1"
    record_ip="\$2"
    record_has_ip="false"

    record_output="\$(ipa dnsrecord-show "\${CLUSTER_DOMAIN}" "\${record_name}" --raw 2>/dev/null || true)"

    if [[ -n "\${record_output}" ]]; then
        while IFS= read -r record_line; do
            record_line="\${record_line#"\${record_line%%[![:space:]]*}"}"

            if [[ "\${record_line}" == "arecord: \${record_ip}" ]]; then
                record_has_ip="true"
            fi
        done <<< "\${record_output}"

        if [[ "\${record_has_ip}" == "true" ]]; then
            echo "DNS record \${record_name} already points to \${record_ip}."
        else
            ipa dnsrecord-mod "\${CLUSTER_DOMAIN}" "\${record_name}" --a-rec "\${record_ip}"
        fi
    else
        if ipa dnsrecord-add "\${CLUSTER_DOMAIN}" "\${record_name}" --a-rec "\${record_ip}" --a-create-reverse >/dev/null 2>&1; then
            echo "Created DNS record \${record_name} pointing to \${record_ip} with a reverse record."
        else
            ipa dnsrecord-add "\${CLUSTER_DOMAIN}" "\${record_name}" --a-rec "\${record_ip}"
        fi
    fi
}

# Create the records needed by the appliance install and demo.
ensure_a_record "\${FOUNDRY_HOSTNAME%%.*}" "\${FOUNDRY_IP}"
ensure_a_record "\${MIRROR_REGISTRY_NAME}" "\${FOUNDRY_IP}"
ensure_a_record "api" "\${API_IP}"
ensure_a_record "api-int" "\${API_IP}"
ensure_a_record "*.apps" "\${INGRESS_IP}"
ensure_a_record "\${NODE_1_NAME}" "\${NODE_1_IP}"
ensure_a_record "\${NODE_2_NAME}" "\${NODE_2_IP}"
ensure_a_record "\${NODE_3_NAME}" "\${NODE_3_IP}"

# Confirm IdM and the integrated DNS service are healthy before moving on.
ipactl status
dig "@\${FOUNDRY_IP}" "\${FOUNDRY_HOSTNAME}" +short
dig "@\${FOUNDRY_IP}" "api.\${CLUSTER_DOMAIN}" +short

#### These steps configure NTP for the appliance network

# chrony follows upstream time when connected and keeps serving local time offline.
cat > /etc/chrony.conf <<CHRONY_CONF
pool 2.rhel.pool.ntp.org iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
allow \${FOUNDRY_CIDR}
local stratum 10
leapsectz right/UTC
logdir /var/log/chrony
CHRONY_CONF

# Check the generated NTP configuration before restarting the service.
chronyd -p -f /etc/chrony.conf >/dev/null

systemctl enable chronyd.service
systemctl restart chronyd.service

#### These steps configure the foundry web staging endpoint

# Expose staged content for appliance image and ISO workflows.
cat > /etc/httpd/conf.d/appliance-install.conf <<HTTPD_CONF
Alias /assets/ "\${HTTP_ROOT}/assets/"
Alias /images/ "\${HTTP_ROOT}/images/"
Alias /iso/ "\${HTTP_ROOT}/iso/"
Alias /mirror/ "\${HTTP_ROOT}/mirror/"
Alias /openshift/ "\${HTTP_ROOT}/openshift/"

<Directory "\${HTTP_ROOT}">
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>
HTTPD_CONF

# Check the generated web server configuration before restarting the service.
httpd -t

systemctl enable httpd.service
systemctl restart httpd.service

#### These steps open foundry service ports

# Open the ports expected by DNS, NTP, HTTP, HTTPS, and a future local registry.
systemctl enable firewalld.service
systemctl start firewalld.service

ensure_firewall_service() {
    local service_name

    service_name="\$1"

    if firewall-cmd --permanent --query-service="\${service_name}" >/dev/null 2>&1; then
        echo "Firewall service \${service_name} is already enabled."
    else
        firewall-cmd --permanent --add-service="\${service_name}"
    fi
}

ensure_firewall_port() {
    local port_value

    port_value="\$1"

    if firewall-cmd --permanent --query-port="\${port_value}" >/dev/null 2>&1; then
        echo "Firewall port \${port_value} is already enabled."
    else
        firewall-cmd --permanent --add-port="\${port_value}"
    fi
}

ensure_firewall_service dns
ensure_firewall_service ntp
ensure_firewall_service http
ensure_firewall_service https
ensure_firewall_service kerberos
ensure_firewall_service kpasswd
ensure_firewall_service ldap
ensure_firewall_service ldaps
ensure_firewall_port 5000/tcp
firewall-cmd --reload

#### These steps record appliance-builder environment defaults

# Operators can source this file before running the openshift-appliance builder.
cat > /etc/profile.d/appliance-foundry.sh <<PROFILE_CONF
export APPLIANCE_ASSETS="\${ASSETS_DIR}"
export APPLIANCE_IMAGE="\${BUILDER_IMAGE}"
PROFILE_CONF

echo "Foundry services are configured."
REMOTE_SCRIPT
