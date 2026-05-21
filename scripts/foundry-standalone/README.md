# Standalone Foundry Scripts

These scripts use an existing RHEL 10.x server as a standalone appliance image
builder. They do not create a foundry VM, do not configure OVS or libvirt, and
do not install IdM, DNS, NTP, HTTP staging, or Cockpit services.

Use this path when the target host already has flat networking with internet
access through its normal default gateway and only needs to mirror content and
produce `appliance.raw`.

## Local Config

Create ignored local config from tracked examples:

```bash
cp config/foundry-standalone.env.example config/foundry-standalone.env
cp config/rhsm.env.example config/rhsm.env
cp config/appliance.env.example config/appliance.env
cp config/operators.env.example config/operators.env
cp config/additional-images.env.example config/additional-images.env
```

Edit those ignored files for the target host and target appliance content.
Private registry credentials stay in the pull secret referenced by
`APPLIANCE_PULL_SECRET_FILE`.

## Run Order

Run each command from the repository root on the operator workstation:

```bash
./scripts/foundry-standalone/01-register-rhn.sh
./scripts/foundry-standalone/02-install-packages.sh
./scripts/foundry-standalone/03-verify-host.sh
./scripts/foundry-standalone/04-prepare-appliance-assets.sh
./scripts/foundry-standalone/05-build-appliance-image.sh

# Optional: copy appliance.raw back to the operator workstation.
./scripts/foundry-standalone/06-fetch-appliance-image.sh
```

The finished image is on the standalone host at:

```text
${APPLIANCE_ASSETS_DIR}/appliance.raw
```

The default value from `config/appliance.env.example` is:

```text
/srv/appliance/assets/appliance.raw
```

## Script Roles

| Script | Purpose |
| --- | --- |
| `01-register-rhn.sh` | Register the existing RHEL 10.x host and enable required RHEL repositories. |
| `02-install-packages.sh` | Install only container, image, and troubleshooting tools needed for the build. |
| `03-verify-host.sh` | Verify RHEL 10.x, default route, DNS, registry reachability, and required tools. |
| `04-prepare-appliance-assets.sh` | Copy the pull secret to the standalone host and write `appliance-config.yaml`. |
| `05-build-appliance-image.sh` | Run the OpenShift appliance builder container and produce `appliance.raw`. |
| `06-fetch-appliance-image.sh` | Optionally fetch `appliance.raw` to an ignored local output directory. |

Changing `config/operators.env`, `config/additional-images.env`, or the pull
secret changes the content baked into `appliance.raw`. Rerun scripts `04` and
`05` after changing mirrored content.
