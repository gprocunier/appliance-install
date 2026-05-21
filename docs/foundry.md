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
- `APPLIANCE_FOUNDRY_CONSOLE_PASSWORD`, which unlocks console login for
  `APPLIANCE_FOUNDRY_USER` and `cloud-user`
- `APPLIANCE_IDM_DIRECTORY_MANAGER_PASSWORD`
- `APPLIANCE_IDM_ADMIN_PASSWORD`

Put the readable console password string in ignored `config/foundry.env`:

```bash
APPLIANCE_FOUNDRY_CONSOLE_PASSWORD="replace-with-console-password"
```

The scripts convert that string to a local SHA-512 password hash before applying
it. The `APPLIANCE_FOUNDRY_USER` account defaults to `appliance` and has
passwordless sudo. The `cloud-user` account receives the same console password.
Root remains disabled by default.

## Run Order

Run these from the repository root on the operator workstation:

```bash
./scripts/06-create-foundry-vm.sh
./scripts/07-configure-foundry-console.sh
./scripts/08-configure-foundry-services.sh
./scripts/09-verify-foundry-services.sh
```

`06-create-foundry-vm.sh` creates the VM on the virtualization host.

It does not attach the staged RHEL cloud image directly. It copies that image to
a standalone foundry QCOW2, resizes the copy, then boots it with a NoCloud
cloud-init seed ISO for hostname, SSH key, and network configuration.

The VM uses VNC graphics bound to `127.0.0.1` on the virtualization host. That
keeps the VNC service off the lab networks while still giving Cockpit a
graphical console to proxy.

`07-configure-foundry-console.sh` sets the configured console password on
`appliance` and `cloud-user`. It also keeps `appliance` configured for
passwordless sudo.

`08-configure-foundry-services.sh` reaches foundry through the virtualization
host and configures:

- IdM with integrated DNS for `appliance.workshop.lan`
- NTP service for `172.16.10.0/24`
- web staging directories under `/srv/appliance`
- podman and image-copy tooling for later appliance-builder work
- environment defaults for `APPLIANCE_ASSETS` and `APPLIANCE_IMAGE`

`09-verify-foundry-services.sh` checks the service state and confirms the DNS,
NTP, and web staging endpoints respond.

## Rebuild Foundry

If foundry needs to be recreated, remove the VM and generated disks first.
Script `06` intentionally refuses to overwrite an existing domain or disk.

Run the cleanup on the virtualization host:

```bash
virsh destroy foundry || true
virsh undefine foundry --nvram --remove-all-storage
rm -rf /var/lib/libvirt/images/foundry-seed
rm -f /var/lib/libvirt/images/foundry.qcow2
rm -f /var/lib/libvirt/images/foundry-seed.iso
```

Adjust the paths if `APPLIANCE_FOUNDRY_NAME` or `APPLIANCE_FOUNDRY_IMAGE_DIR`
are changed from the tracked defaults.

Then rerun from the operator workstation:

```bash
./scripts/06-create-foundry-vm.sh
./scripts/07-configure-foundry-console.sh
./scripts/08-configure-foundry-services.sh
./scripts/09-verify-foundry-services.sh
```

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
