# Scripts

Scripts in this directory should be numbered in the order an operator runs
them. Keep each script focused on one setup phase.

Run numbered scripts from the repository root. The scripts load local
configuration from `config/*.env` and use `scripts/lib/remote.sh` to connect to
the target virtualization host over SSH.

`scripts/lib/remote.sh` is shared helper code, not a script to run directly.
See `docs/execution-model.md` for the full execution model.

Style rules:

- Use names like `01-prepare-host.sh`, `02-create-foundry.sh`, and
  `03-create-ocp-vms.sh`.
- Avoid clever pipe-heavy one-liners.
- Prefer readable, commented commands.
- Use `####` for high-level sections.
- Use `#` for important individual steps.
