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
APPLIANCE_BUILDER_IMAGE="${APPLIANCE_BUILDER_IMAGE:-catalog.redhat.com/software/containers/assisted/agentpreinstall-image-builder-rhel9/65a55174031d94dbea7f2e00}"

#### These steps validate foundry service settings before making changes

# Keep DNS, NTP, and filesystem values inside the formats their services accept.
validate_non_empty "RHSM_ORG_ID" "${RHSM_ORG_ID}"
validate_non_empty "RHSM_ACTIVATION_KEY" "${RHSM_ACTIVATION_KEY}"
validate_fqdn "APPLIANCE_CLUSTER_DOMAIN" "${APPLIANCE_CLUSTER_DOMAIN}"
validate_fqdn "APPLIANCE_IDM_REALM" "${APPLIANCE_IDM_REALM}"
validate_non_empty "APPLIANCE_IDM_DIRECTORY_MANAGER_PASSWORD" "${APPLIANCE_IDM_DIRECTORY_MANAGER_PASSWORD}"
validate_non_empty "APPLIANCE_IDM_ADMIN_PASSWORD" "${APPLIANCE_IDM_ADMIN_PASSWORD}"
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

if [[ "${APPLIANCE_IDM_ADMIN_PASSWORD}" == replace-with-* ]]; then
    fail "APPLIANCE_IDM_ADMIN_PASSWORD must be changed in config/foundry.env."
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
printf -v FOUNDRY_HOSTNAME_REMOTE '%q' "${APPLIANCE_FOUNDRY_HOSTNAME}"
printf -v FOUNDRY_IP_REMOTE '%q' "${APPLIANCE_FOUNDRY_APPLIANCE_IP}"
printf -v FOUNDRY_CIDR_REMOTE '%q' "${APPLIANCE_FOUNDRY_APPLIANCE_CIDR}"
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
FOUNDRY_HOSTNAME=${FOUNDRY_HOSTNAME_REMOTE}
FOUNDRY_IP=${FOUNDRY_IP_REMOTE}
FOUNDRY_CIDR=${FOUNDRY_CIDR_REMOTE}
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

#### These steps register foundry and install service packages

# Register foundry only when it is not already registered.
if subscription-manager identity >/dev/null 2>&1; then
    echo "Foundry is already registered with Red Hat."
else
    subscription-manager register --org="\${RHSM_ORG_ID}" --activationkey="\${RHSM_ACTIVATION_KEY}"
fi

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

#### These steps install DNS, NTP, web, and image-prep tooling

# Install foundry packages in one transaction for predictable dependency solving.
dnf install -y \
    bind-utils \
    chrony \
    curl \
    firewalld \
    httpd \
    ipa-server \
    ipa-server-dns \
    jq \
    podman \
    skopeo \
    tar \
    gzip

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
if [[ -f /etc/ipa/default.conf ]]; then
    echo "IdM is already installed on foundry."
else
    ipa-server-install \
        --unattended \
        --setup-dns \
        --no-forwarders \
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
printf '%s\n' "\${IDM_ADMIN_PASSWORD}" | kinit admin

ensure_a_record() {
    local record_name
    local record_ip

    record_name="\$1"
    record_ip="\$2"

    if ipa dnsrecord-show "\${CLUSTER_DOMAIN}" "\${record_name}" >/dev/null 2>&1; then
        ipa dnsrecord-mod "\${CLUSTER_DOMAIN}" "\${record_name}" --a-rec "\${record_ip}"
    else
        ipa dnsrecord-add "\${CLUSTER_DOMAIN}" "\${record_name}" --a-rec "\${record_ip}" --a-create-reverse || \
            ipa dnsrecord-add "\${CLUSTER_DOMAIN}" "\${record_name}" --a-rec "\${record_ip}"
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
firewall-cmd --permanent --add-service=dns
firewall-cmd --permanent --add-service=ntp
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-service=kerberos
firewall-cmd --permanent --add-service=kpasswd
firewall-cmd --permanent --add-service=ldap
firewall-cmd --permanent --add-service=ldaps
firewall-cmd --permanent --add-port=5000/tcp
firewall-cmd --reload

#### These steps record appliance-builder environment defaults

# Operators can source this file before running the openshift-appliance builder.
cat > /etc/profile.d/appliance-foundry.sh <<PROFILE_CONF
export APPLIANCE_ASSETS="\${ASSETS_DIR}"
export APPLIANCE_IMAGE="\${BUILDER_IMAGE}"
PROFILE_CONF

echo "Foundry services are configured."
REMOTE_SCRIPT
