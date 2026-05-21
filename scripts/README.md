# Scripts

Scripts in this directory should be numbered in the order an operator runs
them. Keep each script focused on one setup phase.

Run numbered scripts from the repository root. The scripts load local
configuration from `config/*.env` and use `scripts/lib/remote.sh` to connect to
the target virtualization host over SSH. Scripts that operate inside foundry use
the virtualization host as an SSH jump path.

`scripts/lib/remote.sh` is shared helper code, not a script to run directly.
See `docs/execution-model.md` for the full execution model.

For an existing RHEL 10.x host that should only mirror content and produce
`appliance.raw`, use `scripts/foundry-standalone/` instead of the main
virtualized lab flow. That path does not configure OVS, libvirt, IdM, DNS, NTP,
HTTP staging, Cockpit, or OpenShift deployment VMs.

Use the root `README.md` for the golden path command list. This file is only a
script-directory summary.

| Scripts | Purpose |
| --- | --- |
| `01` through `05` | Prepare and verify the virtualization host. |
| `06` through `09` | Create, configure, and verify foundry. |
| `10` through `12` | Prepare OpenShift appliance assets, build `appliance.raw`, and create the Agent Installer config ISO on foundry. |
| `13` through `16` | Create or reimage `ocp-01`, `ocp-02`, and `ocp-03`, watch the install, then verify the cluster. |

Operational notes:

- Script `02` reboots the virtualization host; wait for SSH before running
  script `03`.
- Script `06` waits for foundry SSH after booting the VM.
- Script `08`, script `11`, and script `15` can have long quiet phases while
  packages install, content mirrors, or the OpenShift install settles.
- Script `14` is reserved for reimage cleanup. Do not run it between first VM
  creation and install watch.
- If `config/operators.env` or `config/additional-images.env` changes, rerun
  scripts `10` and `11`, then run script `13` with
  `APPLIANCE_REFRESH_BASE_IMAGE=true`.
- Script `10` validates the pull secret JSON and fails if placeholder auth
  values are still present.

Style rules:

- Use names like `01-prepare-host.sh`, `02-create-foundry.sh`, and
  `03-create-ocp-vms.sh`.
- Avoid clever pipe-heavy one-liners.
- Prefer readable, commented commands.
- Use `####` for high-level sections.
- Use `#` for important individual steps.
