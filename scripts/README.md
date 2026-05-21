# Scripts

Scripts in this directory should be numbered in the order an operator runs
them. Keep each script focused on one setup phase.

Run numbered scripts from the repository root. The scripts load local
configuration from `config/*.env` and use `scripts/lib/remote.sh` to connect to
the target virtualization host over SSH.

`scripts/lib/remote.sh` is shared helper code, not a script to run directly.
See `docs/execution-model.md` for the full execution model.

Current host-prep order:

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

Style rules:

- Use names like `01-prepare-host.sh`, `02-create-foundry.sh`, and
  `03-create-ocp-vms.sh`.
- Avoid clever pipe-heavy one-liners.
- Prefer readable, commented commands.
- Use `####` for high-level sections.
- Use `#` for important individual steps.
