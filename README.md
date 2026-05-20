# Appliance Install

Customer-demo setup assets for the Calabi on-prem OpenShift appliance lab.

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
