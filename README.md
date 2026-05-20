# Appliance Install

Customer-demo setup assets for the Calabi on-prem OpenShift appliance lab.

## Execution Model

Run this repository from the operator workstation. The numbered scripts connect
to the virtualization host over SSH and make changes there.

```text
operator workstation
  -> scripts/01-register-rhn.sh
  -> scripts/02-install-host-packages.sh
  -> scripts/03-enable-host-services.sh
  -> scripts/04-verify-virt-host.sh
       |
       +-- SSH to the configured virtualization host
```

Before running host setup, create local config files from the examples:

```bash
cp config/host.env.example config/host.env
cp config/rhsm.env.example config/rhsm.env
```

Edit those local files for the target environment. They are ignored by git.

Current host-prep order:

```bash
./scripts/01-register-rhn.sh
./scripts/02-install-host-packages.sh
./scripts/03-enable-host-services.sh
./scripts/04-verify-virt-host.sh
```

`scripts/lib/remote.sh` is not an operator step. It is a shared helper used by
the numbered scripts to load `config/*.env` and run simple SSH commands on the
target host.

See [Execution Model](docs/execution-model.md) for more detail.

## Folder Tree

```text
appliance-install/
  config/
    host.env.example
    rhsm.env.example
  docs/
    folder-tree.md
  scripts/
    01-register-rhn.sh
    02-install-host-packages.sh
    03-enable-host-services.sh
    04-verify-virt-host.sh
    lib/
      remote.sh
```

The tracked `config/*.example` files document required values with sanitized
placeholders. Local files such as `config/host.env` and `config/rhsm.env` are
ignored by git.

## Script Style

Setup work in this repository should be codified as numbered shell scripts:

```text
scripts/
  01-prepare-host.sh
  02-create-foundry.sh
  03-create-ocp-vms.sh
```

Keep scripts readable. Prefer clear sequential commands over dense one-liners.
Use high-level section comments with `####`, and use single `#` comments for
important individual steps.

Example:

```bash
#### These steps setup Cockpit and libvirt

# Install the virtualization packages
dnf install -y cockpit cockpit-machines libvirt qemu-kvm virt-install
```
