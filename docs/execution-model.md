# Execution Model

This repository is run from an operator workstation against a remote
virtualization host.

The operator does not run most setup commands by hand on the host. Instead, the
operator runs numbered scripts from the repository root. Those scripts load
local configuration and use SSH to make the requested change on the target host.

```text
operator workstation
  config/host.env
  config/rhsm.env
  scripts/01-register-rhn.sh
        |
        +-- SSH
              |
              v
            virtualization host
```

## Local Config Files

Create local config from the tracked examples:

```bash
cp config/host.env.example config/host.env
cp config/rhsm.env.example config/rhsm.env
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

## Host Prep Order

Run these from the repository root:

```bash
./scripts/01-register-rhn.sh
./scripts/02-install-host-packages.sh
./scripts/03-enable-host-services.sh
./scripts/04-verify-virt-host.sh
```

## What remote.sh Does

`scripts/lib/remote.sh` is shared helper code. It is sourced by the numbered
scripts and should not be run directly.

It provides small helper functions:

- `load_host_config`: loads `config/host.env`
- `load_rhsm_config`: loads `config/rhsm.env`
- `run_remote`: runs one command over SSH
- `run_remote_bash`: runs a readable multi-line bash block over SSH

The purpose is to keep each numbered script readable while avoiding duplicate
SSH setup code in every file.

## Publishability Rule

Tracked files should remain publishable. Put real environment-specific values in
ignored `config/*.env` files. Keep tracked examples sanitized.
