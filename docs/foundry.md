# Foundry VM

Foundry is the controlled boundary between the upstream network and the
OVS-only appliance network.

It is dual-homed:

- one NIC on the upstream libvirt network for downloads and mirroring
- one NIC on `lab-switch` for DNS, NTP, and staged content

The OpenShift VMs should use foundry for IdM-backed DNS and NTP on the
appliance network.

## Local Config

Create local foundry config from the tracked example:

```bash
cp config/foundry.env.example config/foundry.env
```

Edit `config/foundry.env` for the target lab. The real file is ignored by git.

The important operator-provided values are:

- `APPLIANCE_FOUNDRY_BASE_IMAGE`, which must point to a RHEL cloud image that
  already exists on the virtualization host
- `APPLIANCE_IDM_DIRECTORY_MANAGER_PASSWORD`
- `APPLIANCE_IDM_ADMIN_PASSWORD`

## Run Order

Run these from the repository root on the operator workstation:

```bash
./scripts/06-create-foundry-vm.sh
./scripts/07-configure-foundry-services.sh
./scripts/08-verify-foundry-services.sh
```

`06-create-foundry-vm.sh` creates the VM on the virtualization host.

`07-configure-foundry-services.sh` reaches foundry through the virtualization
host and configures:

- IdM with integrated DNS for `appliance.workshop.lan`
- NTP service for `172.16.10.0/24`
- web staging directories under `/srv/appliance`
- podman and image-copy tooling for later appliance-builder work
- environment defaults for `APPLIANCE_ASSETS` and `APPLIANCE_IMAGE`

`08-verify-foundry-services.sh` checks the service state and confirms the DNS,
NTP, and web staging endpoints respond.

## Published DNS Defaults

The tracked defaults match the lab proposal:

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

Change these in `config/foundry.env` if the lab addressing changes.
