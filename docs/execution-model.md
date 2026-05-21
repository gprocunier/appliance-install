# Execution Model

This repository is run from an operator workstation against a remote
virtualization host.

The operator does not run most setup commands by hand on the host. Instead, the
operator runs numbered scripts from the repository root. Those scripts load
local configuration and use SSH to make the requested change on the target host.

```text
operator workstation
  config/host.env
  config/foundry.env
  config/network.env
  config/rhsm.env
  scripts/01-register-rhn.sh
        |
        +-- SSH
              |
              v
            virtualization host
```

## Run Locations

| Thing | Where it runs | Notes |
| --- | --- | --- |
| Repository clone | Operator workstation | This is where the operator runs `./scripts/*.sh`. |
| `config/*.env` | Operator workstation | Local files, ignored by git. |
| Numbered scripts | Operator workstation | Each script connects to the configured host over SSH. |
| `scripts/lib/remote.sh` | Sourced by numbered scripts | Helper functions only; do not run directly. |
| RHSM registration commands | Virtualization host | Sent over SSH by `01-register-rhn.sh`. |
| Package installation commands | Virtualization host | Sent over SSH by `02-install-host-packages.sh`. |
| Service enablement commands | Virtualization host | Sent over SSH by `03-enable-host-services.sh`. |
| OVS/libvirt network commands | Virtualization host | Sent over SSH by `04-configure-ovs-networks.sh`. |
| Foundry VM creation | Virtualization host | Sent over SSH by `06-create-foundry-vm.sh`. |
| Foundry service commands | Foundry VM | Sent through the virtualization host jump path by `07-configure-foundry-services.sh`. |
| `/usr/local/sbin/appliance-install-net.sh` | Virtualization host | Generated persistent OVS setup script. |
| `appliance-install-net.service` | Virtualization host | Generated systemd service that reruns OVS setup at boot. |
| `dnsmasq`, `chronyd`, `httpd` | Foundry VM | Configured by script `07` for the appliance network. |

## Local Config Files

Create local config from the tracked examples:

```bash
cp config/host.env.example config/host.env
cp config/foundry.env.example config/foundry.env
cp config/rhsm.env.example config/rhsm.env
cp config/network.env.example config/network.env
```

`config/host.env` describes how the operator workstation reaches the
virtualization host:

```bash
APPLIANCE_HOST="replace-with-virt-host-address"
APPLIANCE_HOST_USER="root"
APPLIANCE_HOST_SSH_KEY="${HOME}/.ssh/id_ed25519"
```

`config/rhsm.env` contains operator-provided Red Hat registration values:

```bash
RHSM_ORG_ID="replace-with-red-hat-org-id"
RHSM_ACTIVATION_KEY="replace-with-red-hat-activation-key"
```

Both files are ignored by git through `config/*.env`.

`config/network.env` describes the OVS-only appliance networks. The initial
design keeps the OpenShift VMs on an OVS bridge without a physical uplink.

`config/foundry.env` describes the foundry VM, DNS records, NTP serving network,
and appliance-builder workspace defaults.

## Host Prep Order

Run these from the repository root:

```bash
./scripts/01-register-rhn.sh
./scripts/02-install-host-packages.sh
./scripts/03-enable-host-services.sh
./scripts/04-configure-ovs-networks.sh
./scripts/05-verify-virt-host.sh
./scripts/06-create-foundry-vm.sh
./scripts/07-configure-foundry-services.sh
./scripts/08-verify-foundry-services.sh
```

## What remote.sh Does

`scripts/lib/remote.sh` is shared helper code. It is sourced by the numbered
scripts and should not be run directly.

It provides small helper functions:

- `load_host_config`: loads `config/host.env`
- `load_rhsm_config`: loads `config/rhsm.env`
- `load_network_config`: loads `config/network.env`
- `load_foundry_config`: loads `config/foundry.env`
- `run_remote`: runs one command over SSH
- `run_remote_bash`: runs a readable multi-line bash block over SSH
- `run_foundry`: runs one command on foundry through the virtualization host
- `run_foundry_bash`: runs a readable multi-line bash block on foundry

The purpose is to keep each numbered script readable while avoiding duplicate
SSH setup code in every file.

## Publishability Rule

Tracked files should remain publishable. Put real environment-specific values in
ignored `config/*.env` files. Keep tracked examples sanitized.
