# Standalone Foundry

The standalone foundry path uses an existing RHEL 10.x server to mirror content
and produce the OpenShift appliance disk image. It is for build-only workflows
where the host already has normal flat networking and internet access through
its default gateway.

This path intentionally skips services that are only needed for the virtualized
Calabi lab topology:

- no foundry VM creation
- no Open vSwitch or libvirt networking
- no IdM, DNS, or NTP serving
- no HTTP staging service
- no Cockpit or VM management setup
- no `ocp-01`, `ocp-02`, or `ocp-03` VM creation

## Config

Create local config from tracked examples:

```bash
cp config/foundry-standalone.env.example config/foundry-standalone.env
cp config/rhsm.env.example config/rhsm.env
cp config/appliance.env.example config/appliance.env
cp config/operators.env.example config/operators.env
cp config/additional-images.env.example config/additional-images.env
```

The important standalone values are:

- `APPLIANCE_STANDALONE_HOST`: existing RHEL 10.x host address or DNS name
- `APPLIANCE_STANDALONE_USER`: SSH user, usually `root` or a passwordless sudo
  user
- `APPLIANCE_STANDALONE_SSH_KEY`: SSH private key used by the operator
  workstation
- `APPLIANCE_PULL_SECRET_FILE`: ignored local pull secret with all required
  registry auth
- `APPLIANCE_ASSETS_DIR`: remote directory where `appliance-config.yaml`,
  mirror working data, and `appliance.raw` are written

The standalone scripts reuse:

- `config/appliance.env` for OpenShift release and build settings
- `config/operators.env` for operator catalog/package/channel content
- `config/additional-images.env` for non-operator image refs
- `config/rhsm.env` for Red Hat registration

## Run Order

Run from the repository root on the operator workstation:

```bash
./scripts/foundry-standalone/01-register-rhn.sh
./scripts/foundry-standalone/02-install-packages.sh
./scripts/foundry-standalone/03-verify-host.sh
./scripts/foundry-standalone/04-prepare-appliance-assets.sh
./scripts/foundry-standalone/05-build-appliance-image.sh
```

Optional local fetch:

```bash
./scripts/foundry-standalone/06-fetch-appliance-image.sh
```

## Outputs

The remote output path is:

```text
${APPLIANCE_ASSETS_DIR}/appliance.raw
```

With the tracked defaults, that is:

```text
/srv/appliance/assets/appliance.raw
```

The optional fetch script copies the image to
`APPLIANCE_STANDALONE_LOCAL_OUTPUT_DIR`, which defaults to
`work/foundry-standalone`.

## Content Changes

When registry auth, operator catalogs, operator packages, channels, or
additional image refs change, rerun:

```bash
./scripts/foundry-standalone/04-prepare-appliance-assets.sh
./scripts/foundry-standalone/05-build-appliance-image.sh
```

The standalone path does not generate an Agent Installer config ISO or create
deployment VMs. Use the main numbered workflow when the workshop needs the full
disconnected virtualized lab.
