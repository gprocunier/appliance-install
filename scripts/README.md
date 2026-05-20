# Scripts

Scripts in this directory should be numbered in the order an operator runs
them. Keep each script focused on one setup phase.

Style rules:

- Use names like `01-prepare-host.sh`, `02-create-foundry.sh`, and
  `03-create-ocp-vms.sh`.
- Avoid clever pipe-heavy one-liners.
- Prefer readable, commented commands.
- Use `####` for high-level sections.
- Use `#` for important individual steps.
