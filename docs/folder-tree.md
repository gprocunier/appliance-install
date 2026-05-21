# Folder Tree

This repository keeps executable setup steps separate from local operator
configuration and written notes.

```text
appliance-install/
  README.md
  config/
    foundry.env.example
    host.env.example
    network.env.example
    rhsm.env.example
  docs/
    execution-model.md
    foundry.md
    folder-tree.md
    network-design.md
  scripts/
    01-register-rhn.sh
    02-install-host-packages.sh
    03-enable-host-services.sh
    04-configure-ovs-networks.sh
    05-verify-virt-host.sh
    06-create-foundry-vm.sh
    07-configure-foundry-console.sh
    08-configure-foundry-services.sh
    09-verify-foundry-services.sh
    README.md
    lib/
      remote.sh
```

## Config

`config/host.env.example` documents the target virtualization host and package
repository defaults. Copy it to `config/host.env` before running host setup.

`config/rhsm.env.example` documents the Red Hat registration variables with
sanitized placeholders. The real `config/rhsm.env` file is ignored by git and
must not be committed.

`config/network.env.example` documents the OVS-only appliance networks. The
real `config/network.env` file is ignored by git.

`config/foundry.env.example` documents the foundry VM, DNS records, NTP network,
and staging directories. The real `config/foundry.env` file is ignored by git.

## Scripts

Scripts are numbered in the order an operator should run them. Keep each script
focused on one phase, with readable comments and clear commands.

## Docs

Use this directory for small notes that explain operator decisions, topology,
and customer-demo assumptions.

- `execution-model.md` explains where scripts run and how they reach the
  virtualization host.
- `foundry.md` explains the foundry VM role and service setup.
- `folder-tree.md` explains the repository layout.
- `network-design.md` explains the OVS-only disconnected appliance network.
