#!/usr/bin/env bash
set -euo pipefail

#### These steps configure OVS-only networks for the appliance lab

# Run this script from the operator workstation, in the repository root.
# This script creates OVS and libvirt network state on the virtualization host.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/remote.sh"

load_host_config
load_network_config

APPLIANCE_OVS_BRIDGE="${APPLIANCE_OVS_BRIDGE:-lab-switch}"
APPLIANCE_LIBVIRT_NETWORK="${APPLIANCE_LIBVIRT_NETWORK:-lab-switch}"
APPLIANCE_ENABLE_HOST_IPV4_FORWARDING="${APPLIANCE_ENABLE_HOST_IPV4_FORWARDING:-true}"

APPLIANCE_MACHINE_PORT="${APPLIANCE_MACHINE_PORT:-app-machine}"
APPLIANCE_MACHINE_PORTGROUP="${APPLIANCE_MACHINE_PORTGROUP:-machine-vlan200}"
APPLIANCE_MACHINE_VLAN_ID="${APPLIANCE_MACHINE_VLAN_ID:-200}"
APPLIANCE_MACHINE_GATEWAY_CIDR="${APPLIANCE_MACHINE_GATEWAY_CIDR:-172.16.10.1/24}"

APPLIANCE_STORAGE_PORT="${APPLIANCE_STORAGE_PORT:-app-storage}"
APPLIANCE_STORAGE_PORTGROUP="${APPLIANCE_STORAGE_PORTGROUP:-storage-vlan201}"
APPLIANCE_STORAGE_VLAN_ID="${APPLIANCE_STORAGE_VLAN_ID:-201}"
APPLIANCE_STORAGE_GATEWAY_CIDR="${APPLIANCE_STORAGE_GATEWAY_CIDR:-}"

APPLIANCE_MIGRATION_PORT="${APPLIANCE_MIGRATION_PORT:-app-migrate}"
APPLIANCE_MIGRATION_PORTGROUP="${APPLIANCE_MIGRATION_PORTGROUP:-migration-vlan202}"
APPLIANCE_MIGRATION_VLAN_ID="${APPLIANCE_MIGRATION_VLAN_ID:-202}"
APPLIANCE_MIGRATION_GATEWAY_CIDR="${APPLIANCE_MIGRATION_GATEWAY_CIDR:-}"

validate_linux_interface_name() {
    local label
    local value

    label="$1"
    value="$2"

    if [[ -z "${value}" ]]; then
        echo "${label} must not be empty." >&2
        exit 1
    fi

    if [[ "${#value}" -gt 15 ]]; then
        echo "${label} '${value}' is too long for a Linux interface name." >&2
        echo "Use 15 characters or fewer." >&2
        exit 1
    fi

    if [[ ! "${value}" =~ ^[A-Za-z0-9._-]+$ ]]; then
        echo "${label} must contain only letters, numbers, dots, underscores, and hyphens." >&2
        exit 1
    fi
}

validate_vlan_id() {
    local label
    local value

    label="$1"
    value="$2"

    if [[ ! "${value}" =~ ^[0-9]+$ ]] || (( 10#${value} < 1 || 10#${value} > 4094 )); then
        echo "${label} must be a VLAN ID from 1 to 4094." >&2
        exit 1
    fi
}

#### These steps validate network settings before touching the host

# Linux interface names must be short and safe for ip and OVS commands.
validate_linux_interface_name "APPLIANCE_OVS_BRIDGE" "${APPLIANCE_OVS_BRIDGE}"
validate_linux_interface_name "APPLIANCE_MACHINE_PORT" "${APPLIANCE_MACHINE_PORT}"
validate_linux_interface_name "APPLIANCE_STORAGE_PORT" "${APPLIANCE_STORAGE_PORT}"
validate_linux_interface_name "APPLIANCE_MIGRATION_PORT" "${APPLIANCE_MIGRATION_PORT}"

# Libvirt names and portgroups are written into XML and command arguments.
validate_simple_name "APPLIANCE_LIBVIRT_NETWORK" "${APPLIANCE_LIBVIRT_NETWORK}"
validate_simple_name "APPLIANCE_MACHINE_PORTGROUP" "${APPLIANCE_MACHINE_PORTGROUP}"
validate_simple_name "APPLIANCE_STORAGE_PORTGROUP" "${APPLIANCE_STORAGE_PORTGROUP}"
validate_simple_name "APPLIANCE_MIGRATION_PORTGROUP" "${APPLIANCE_MIGRATION_PORTGROUP}"

# VLAN IDs, CIDRs, and booleans should fail before any remote edits are made.
validate_vlan_id "APPLIANCE_MACHINE_VLAN_ID" "${APPLIANCE_MACHINE_VLAN_ID}"
validate_vlan_id "APPLIANCE_STORAGE_VLAN_ID" "${APPLIANCE_STORAGE_VLAN_ID}"
validate_vlan_id "APPLIANCE_MIGRATION_VLAN_ID" "${APPLIANCE_MIGRATION_VLAN_ID}"
validate_ipv4_cidr "APPLIANCE_MACHINE_GATEWAY_CIDR" "${APPLIANCE_MACHINE_GATEWAY_CIDR}"
validate_boolean "APPLIANCE_ENABLE_HOST_IPV4_FORWARDING" "${APPLIANCE_ENABLE_HOST_IPV4_FORWARDING}"

if [[ -n "${APPLIANCE_STORAGE_GATEWAY_CIDR}" ]]; then
    validate_ipv4_cidr "APPLIANCE_STORAGE_GATEWAY_CIDR" "${APPLIANCE_STORAGE_GATEWAY_CIDR}"
fi

if [[ -n "${APPLIANCE_MIGRATION_GATEWAY_CIDR}" ]]; then
    validate_ipv4_cidr "APPLIANCE_MIGRATION_GATEWAY_CIDR" "${APPLIANCE_MIGRATION_GATEWAY_CIDR}"
fi

printf -v OVS_BRIDGE_REMOTE '%q' "${APPLIANCE_OVS_BRIDGE}"
printf -v LIBVIRT_NETWORK_REMOTE '%q' "${APPLIANCE_LIBVIRT_NETWORK}"
printf -v ENABLE_FORWARDING_REMOTE '%q' "${APPLIANCE_ENABLE_HOST_IPV4_FORWARDING}"
printf -v MACHINE_PORT_REMOTE '%q' "${APPLIANCE_MACHINE_PORT}"
printf -v MACHINE_PORTGROUP_REMOTE '%q' "${APPLIANCE_MACHINE_PORTGROUP}"
printf -v MACHINE_VLAN_REMOTE '%q' "${APPLIANCE_MACHINE_VLAN_ID}"
printf -v MACHINE_GATEWAY_REMOTE '%q' "${APPLIANCE_MACHINE_GATEWAY_CIDR}"
printf -v STORAGE_PORT_REMOTE '%q' "${APPLIANCE_STORAGE_PORT}"
printf -v STORAGE_PORTGROUP_REMOTE '%q' "${APPLIANCE_STORAGE_PORTGROUP}"
printf -v STORAGE_VLAN_REMOTE '%q' "${APPLIANCE_STORAGE_VLAN_ID}"
printf -v STORAGE_GATEWAY_REMOTE '%q' "${APPLIANCE_STORAGE_GATEWAY_CIDR}"
printf -v MIGRATION_PORT_REMOTE '%q' "${APPLIANCE_MIGRATION_PORT}"
printf -v MIGRATION_PORTGROUP_REMOTE '%q' "${APPLIANCE_MIGRATION_PORTGROUP}"
printf -v MIGRATION_VLAN_REMOTE '%q' "${APPLIANCE_MIGRATION_VLAN_ID}"
printf -v MIGRATION_GATEWAY_REMOTE '%q' "${APPLIANCE_MIGRATION_GATEWAY_CIDR}"

run_remote_bash <<REMOTE_SCRIPT
set -euo pipefail

OVS_BRIDGE=${OVS_BRIDGE_REMOTE}
LIBVIRT_NETWORK=${LIBVIRT_NETWORK_REMOTE}
LIBVIRT_XML_PATH="/etc/libvirt/\${LIBVIRT_NETWORK}.xml"
ENABLE_HOST_IPV4_FORWARDING=${ENABLE_FORWARDING_REMOTE}
MACHINE_PORT=${MACHINE_PORT_REMOTE}
MACHINE_PORTGROUP=${MACHINE_PORTGROUP_REMOTE}
MACHINE_VLAN=${MACHINE_VLAN_REMOTE}
MACHINE_GATEWAY=${MACHINE_GATEWAY_REMOTE}
STORAGE_PORT=${STORAGE_PORT_REMOTE}
STORAGE_PORTGROUP=${STORAGE_PORTGROUP_REMOTE}
STORAGE_VLAN=${STORAGE_VLAN_REMOTE}
STORAGE_GATEWAY=${STORAGE_GATEWAY_REMOTE}
MIGRATION_PORT=${MIGRATION_PORT_REMOTE}
MIGRATION_PORTGROUP=${MIGRATION_PORTGROUP_REMOTE}
MIGRATION_VLAN=${MIGRATION_VLAN_REMOTE}
MIGRATION_GATEWAY=${MIGRATION_GATEWAY_REMOTE}

#### These steps install the persistent OVS network setup script

cat > /usr/local/sbin/appliance-install-net.sh <<'HOST_SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

OVS_BRIDGE="__OVS_BRIDGE__"
MACHINE_PORT="__MACHINE_PORT__"
MACHINE_VLAN="__MACHINE_VLAN__"
MACHINE_GATEWAY="__MACHINE_GATEWAY__"
STORAGE_PORT="__STORAGE_PORT__"
STORAGE_VLAN="__STORAGE_VLAN__"
STORAGE_GATEWAY="__STORAGE_GATEWAY__"
MIGRATION_PORT="__MIGRATION_PORT__"
MIGRATION_VLAN="__MIGRATION_VLAN__"
MIGRATION_GATEWAY="__MIGRATION_GATEWAY__"

validate_linux_interface_name() {
    local label
    local value

    label="\$1"
    value="\$2"

    if [[ -z "\${value}" ]]; then
        echo "\${label} must not be empty." >&2
        exit 1
    fi

    if [[ "\${#value}" -gt 15 ]]; then
        echo "\${label} '\${value}' is too long for a Linux interface name." >&2
        echo "Use 15 characters or fewer." >&2
        exit 1
    fi
}

#### These steps validate Linux interface names before changing OVS

# Linux network interface names must be 15 characters or fewer.
validate_linux_interface_name "OVS_BRIDGE" "\${OVS_BRIDGE}"
validate_linux_interface_name "MACHINE_PORT" "\${MACHINE_PORT}"
validate_linux_interface_name "STORAGE_PORT" "\${STORAGE_PORT}"
validate_linux_interface_name "MIGRATION_PORT" "\${MIGRATION_PORT}"

#### These steps create the OVS-only appliance switch

# Create the OVS bridge without attaching any physical uplink.
ovs-vsctl --may-exist add-br "\${OVS_BRIDGE}"
ip link set dev "\${OVS_BRIDGE}" up

#### These steps create the OpenShift machine network

# Add the machine-network internal port on VLAN 200.
ovs-vsctl --may-exist add-port "\${OVS_BRIDGE}" "\${MACHINE_PORT}" \
    -- set Port "\${MACHINE_PORT}" tag="\${MACHINE_VLAN}" \
    -- set Interface "\${MACHINE_PORT}" type=internal
ip link set dev "\${MACHINE_PORT}" up

# Give the host an address on the machine network for operator troubleshooting.
if [[ -n "\${MACHINE_GATEWAY}" ]]; then
    ip -4 addr flush dev "\${MACHINE_PORT}"
    ip -4 addr add "\${MACHINE_GATEWAY}" dev "\${MACHINE_PORT}"
fi

#### These steps reserve optional OVS-only cluster networks

# Add the storage-network port without a gateway unless configured.
ovs-vsctl --may-exist add-port "\${OVS_BRIDGE}" "\${STORAGE_PORT}" \
    -- set Port "\${STORAGE_PORT}" tag="\${STORAGE_VLAN}" \
    -- set Interface "\${STORAGE_PORT}" type=internal
ip link set dev "\${STORAGE_PORT}" up
ip -4 addr flush dev "\${STORAGE_PORT}"
if [[ -n "\${STORAGE_GATEWAY}" ]]; then
    ip -4 addr add "\${STORAGE_GATEWAY}" dev "\${STORAGE_PORT}"
fi

# Add the migration-network port without a gateway unless configured.
ovs-vsctl --may-exist add-port "\${OVS_BRIDGE}" "\${MIGRATION_PORT}" \
    -- set Port "\${MIGRATION_PORT}" tag="\${MIGRATION_VLAN}" \
    -- set Interface "\${MIGRATION_PORT}" type=internal
ip link set dev "\${MIGRATION_PORT}" up
ip -4 addr flush dev "\${MIGRATION_PORT}"
if [[ -n "\${MIGRATION_GATEWAY}" ]]; then
    ip -4 addr add "\${MIGRATION_GATEWAY}" dev "\${MIGRATION_PORT}"
fi
HOST_SCRIPT

sed -i "s|__OVS_BRIDGE__|\${OVS_BRIDGE}|g" /usr/local/sbin/appliance-install-net.sh
sed -i "s|__MACHINE_PORT__|\${MACHINE_PORT}|g" /usr/local/sbin/appliance-install-net.sh
sed -i "s|__MACHINE_VLAN__|\${MACHINE_VLAN}|g" /usr/local/sbin/appliance-install-net.sh
sed -i "s|__MACHINE_GATEWAY__|\${MACHINE_GATEWAY}|g" /usr/local/sbin/appliance-install-net.sh
sed -i "s|__STORAGE_PORT__|\${STORAGE_PORT}|g" /usr/local/sbin/appliance-install-net.sh
sed -i "s|__STORAGE_VLAN__|\${STORAGE_VLAN}|g" /usr/local/sbin/appliance-install-net.sh
sed -i "s|__STORAGE_GATEWAY__|\${STORAGE_GATEWAY}|g" /usr/local/sbin/appliance-install-net.sh
sed -i "s|__MIGRATION_PORT__|\${MIGRATION_PORT}|g" /usr/local/sbin/appliance-install-net.sh
sed -i "s|__MIGRATION_VLAN__|\${MIGRATION_VLAN}|g" /usr/local/sbin/appliance-install-net.sh
sed -i "s|__MIGRATION_GATEWAY__|\${MIGRATION_GATEWAY}|g" /usr/local/sbin/appliance-install-net.sh
chmod 0755 /usr/local/sbin/appliance-install-net.sh

#### These steps run the OVS network setup at boot

cat > /etc/systemd/system/appliance-install-net.service <<'UNIT'
[Unit]
Description=Configure appliance-install OVS networks
Wants=network-online.target openvswitch.service
After=network-online.target openvswitch.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/appliance-install-net.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable appliance-install-net.service
systemctl restart appliance-install-net.service

#### These steps define the libvirt network backed by the OVS switch

cat > "\${LIBVIRT_XML_PATH}" <<LIBVIRT_XML
<network>
  <name>\${LIBVIRT_NETWORK}</name>
  <forward mode='bridge'/>
  <bridge name='\${OVS_BRIDGE}'/>
  <virtualport type='openvswitch'/>
  <portgroup name='\${MACHINE_PORTGROUP}' default='yes'>
    <vlan>
      <tag id='\${MACHINE_VLAN}'/>
    </vlan>
  </portgroup>
  <portgroup name='\${STORAGE_PORTGROUP}'>
    <vlan>
      <tag id='\${STORAGE_VLAN}'/>
    </vlan>
  </portgroup>
  <portgroup name='\${MIGRATION_PORTGROUP}'>
    <vlan>
      <tag id='\${MIGRATION_VLAN}'/>
    </vlan>
  </portgroup>
</network>
LIBVIRT_XML

# Define the libvirt network if it does not already exist.
if virsh net-info "\${LIBVIRT_NETWORK}" >/dev/null 2>&1; then
    echo "Libvirt network \${LIBVIRT_NETWORK} already exists."
else
    virsh net-define "\${LIBVIRT_XML_PATH}"
fi

# Ensure the libvirt network starts after reboot.
virsh net-autostart "\${LIBVIRT_NETWORK}"

# Start the libvirt network when it is not already running.
network_active="\$(virsh net-info "\${LIBVIRT_NETWORK}" | sed -n 's/^Active:[[:space:]]*//p')"
if [[ "\${network_active}" == "yes" ]]; then
    echo "Libvirt network \${LIBVIRT_NETWORK} is already active."
else
    virsh net-start "\${LIBVIRT_NETWORK}"
fi

#### These steps keep foundry upstream NAT working

# The libvirt default NAT network needs host IPv4 forwarding for foundry.
# The appliance switch remains disconnected because lab-switch has no uplink or NAT.
rm -f /etc/sysctl.d/99-appliance-install-disconnected.conf

if [[ "\${ENABLE_HOST_IPV4_FORWARDING}" == "true" ]]; then
    forwarding_value="1"
else
    forwarding_value="0"
fi

cat > /etc/sysctl.d/99-appliance-install-libvirt-nat.conf <<SYSCTL
net.ipv4.ip_forward = \${forwarding_value}
SYSCTL
sysctl --system
REMOTE_SCRIPT
