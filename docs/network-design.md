# Network Design

The appliance demo uses Open vSwitch as the lab switch. The OpenShift VMs live
only on networks that exist on that OVS switch.

This gives the demo a clean disconnection story:

- the OpenShift nodes do not have a management or internet-facing NIC
- the OVS appliance switch has no physical uplink
- the host does not provide NAT for the appliance network
- the host disables IPv4 forwarding by default for this demo
- foundry is the controlled boundary between upstream preparation and the
  disconnected install network

## VM Shape

```text
management/upstream network
  |
  +-- foundry first NIC

OVS lab-switch
  |
  +-- foundry appliance NIC
  +-- ocp-01 appliance NIC
  +-- ocp-02 appliance NIC
  +-- ocp-03 appliance NIC
```

The foundry VM is dual-homed. It can prepare content using its upstream NIC,
then serve DNS, NTP, registry, appliance image build artifacts, and config ISO
content to the appliance network.

The OpenShift nodes are single-homed on the appliance network.

See [Foundry VM](foundry.md) for the foundry build and service scripts.

## Initial Networks

The first setup phase creates one OVS bridge and a libvirt network backed by
that bridge:

```text
OVS bridge:       lab-switch
libvirt network:  lab-switch
machine VLAN:     200
machine CIDR:     172.16.10.0/24
host gateway IP:  172.16.10.1/24
```

Storage and migration VLANs are reserved in `config/network.env.example`, but
they are not required for the initial three-node appliance install.

## DNS And NTP

Foundry should provide DNS and NTP on the appliance network.

Recommended names:

```text
foundry.appliance.workshop.lan          172.16.10.10
mirror-registry.appliance.workshop.lan  172.16.10.10

api.appliance.workshop.lan              172.16.10.5
api-int.appliance.workshop.lan          172.16.10.5
*.apps.appliance.workshop.lan           172.16.10.7

ocp-01.appliance.workshop.lan           172.16.10.11
ocp-02.appliance.workshop.lan           172.16.10.12
ocp-03.appliance.workshop.lan           172.16.10.13
```

Create matching PTR records for the fixed addresses.

## Hard Disconnection Demo

To demonstrate disconnection, keep the OpenShift nodes attached only to
`lab-switch`. Do not attach a physical uplink to the OVS bridge, and do
not add host NAT for the appliance network.

The default `config/network.env.example` sets:

```bash
APPLIANCE_DISABLE_HOST_IPV4_FORWARDING="true"
```

That makes the hypervisor a VM host and troubleshooting endpoint, not a router
for the appliance network.

The visible disconnection control is foundry's upstream path. When foundry's
upstream NIC or route is disabled, the cluster remains on the isolated OVS
network and can only use content already staged on foundry.
