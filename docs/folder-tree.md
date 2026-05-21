# Folder Tree

This repository keeps executable setup steps separate from local operator
configuration and written notes.

## Repository Layout

| Path | Purpose |
| --- | --- |
| `README.md` | Repository entry point. |
| `config/*.env.example` | Publishable examples for ignored local operator config. |
| `docs/*.md` | Operator notes and partner-facing runbooks. |
| `scripts/01-*.sh` through `scripts/09-*.sh` | Virtualization host and foundry preparation phases. |
| `scripts/10-*.sh` through `scripts/16-*.sh` | OpenShift appliance asset, VM, reimage, install-watch, and cluster-verification phases. |
| `scripts/README.md` | Script-specific operator notes. |
| `scripts/lib/remote.sh` | Shared SSH and config-loading helpers for numbered scripts. |

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

`config/appliance.env.example` documents the OpenShift 4.21 appliance build,
cluster identity, local pull-secret path placeholder, and OpenShift VM disk
location. The real `config/appliance.env` file is ignored by git.

`config/operators.env.example` documents the default operator catalog, packages,
and channels mirrored into the appliance image. Copy it to ignored
`config/operators.env` when the workshop needs a different operator set.

`config/additional-images.env.example` documents optional non-operator image
refs mirrored into the appliance image. Copy it to ignored
`config/additional-images.env` for private registry content such as IBM Cloud
Pak images.

`config/pull-secret.multi-registry.json.example`,
`config/operators.ibm-cloudpak.env.example`,
`config/additional-images.ibm-cloudpak.env.example`, and
`config/cloudpak.images.example` are sanitized examples for labs that need IBM
Cloud Pak or other private registry content. Copy them to ignored local files
before adding real registry credentials or image lists.

## Scripts

Scripts are numbered in the order an operator should run them. Keep each script
focused on one phase, with readable comments and clear commands.

| Scripts | Purpose |
| --- | --- |
| `01` through `05` | Prepare and verify the virtualization host. |
| `06` through `09` | Create, configure, and verify foundry. |
| `10` through `12` | Prepare OpenShift 4.21 appliance assets, including configured operators and additional images, build `appliance.raw`, and create the Agent Installer config ISO on foundry. |
| `13` through `16` | Create or reimage OpenShift VMs, watch the install, and verify the cluster. |

The OpenShift appliance scripts generate environment-specific YAML and secret
material on foundry. Treat `docs/*.md`, `README.md`, `scripts/README.md`, and
the tracked `config/*.env.example` files as publishable operator guidance only.

## Docs

Use this directory for small notes that explain operator decisions, topology,
and customer-demo assumptions.

- `execution-model.md` explains where scripts run and how they reach the
  virtualization host.
- `foundry.md` explains the foundry VM role and service setup.
- `folder-tree.md` explains the repository layout.
- `network-design.md` explains the OVS-only disconnected appliance network.
- `partner-runbook.md` gives a novice-friendly runbook for the full flow.
- `registry-auth.md` shows how pull-secret auth maps to Red Hat, IBM, Quay, and
  generic private registry content.
