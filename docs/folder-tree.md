# Folder Tree

This repository keeps executable setup steps separate from local operator
configuration and written notes.

```text
appliance-install/
  README.md
  config/
    host.env.example
    rhsm.env.example
  docs/
    execution-model.md
    folder-tree.md
  scripts/
    01-register-rhn.sh
    02-install-host-packages.sh
    03-enable-host-services.sh
    04-verify-virt-host.sh
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

## Scripts

Scripts are numbered in the order an operator should run them. Keep each script
focused on one phase, with readable comments and clear commands.

## Docs

Use this directory for small notes that explain operator decisions, topology,
and customer-demo assumptions.

- `execution-model.md` explains where scripts run and how they reach the
  virtualization host.
- `folder-tree.md` explains the repository layout.
