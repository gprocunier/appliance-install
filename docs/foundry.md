# Foundry VM

Foundry is the controlled boundary between the upstream network and the
OVS-only appliance network.

It is dual-homed:

- one NIC on the upstream libvirt network for downloads and mirroring
- one NIC on `lab-switch` for DNS, NTP, and staged content

The OpenShift VMs should use foundry for IdM-backed DNS and NTP on the
appliance network. Script `10` writes that NTP source into
`agent-config.yaml` as `additionalNTPSources`, using
`APPLIANCE_AGENT_NTP_SOURCE` and defaulting to foundry. This matters in the
disconnected lab because nodes cannot rely on public NTP while bootstrapping.

Foundry also owns the OpenShift appliance build workspace. Scripts `10` through
`12` generate appliance config, build `appliance.raw`, and create the
`agentconfig.noarch.iso` config image on foundry before script `13` pulls those
artifacts directly to the virtualization host.

## Local Config

Create local foundry config from the tracked example:

```bash
cp config/foundry.env.example config/foundry.env
cp config/appliance.env.example config/appliance.env
cp config/operators.env.example config/operators.env
cp config/additional-images.env.example config/additional-images.env
```

Edit both ignored files for the target lab. The real files are ignored by git.

The important operator-provided values are:

- `APPLIANCE_FOUNDRY_BASE_IMAGE`, which must point to a RHEL cloud image that
  already exists on the virtualization host
- `APPLIANCE_FOUNDRY_CONSOLE_PASSWORD`, which unlocks console login for
  `APPLIANCE_FOUNDRY_USER` and `cloud-user`
- `APPLIANCE_IDM_DIRECTORY_MANAGER_PASSWORD`
- `APPLIANCE_IDM_ADMIN_PASSWORD`
- `APPLIANCE_PULL_SECRET_FILE`, which points to the operator-provided pull
  secret file used by script `10`
- `APPLIANCE_CORE_PASSWORD`, which is converted into the appliance image for
  core console access

Put the readable console password string in ignored `config/foundry.env`:

```bash
APPLIANCE_FOUNDRY_CONSOLE_PASSWORD="replace-with-console-password"
```

The scripts convert that string to a local SHA-512 password hash before applying
it. The `APPLIANCE_FOUNDRY_USER` account defaults to `appliance` and has
passwordless sudo. The `cloud-user` account receives the same console password.
Root remains disabled by default.

The two IdM setup passwords are also readable strings in ignored
`config/foundry.env`. They must be at least 8 characters because
`ipa-server-install` rejects shorter values.

`APPLIANCE_IDM_DNS_FORWARDERS` defines upstream DNS servers that foundry can use
for Red Hat CDN and mirroring lookups after IdM takes over `/etc/resolv.conf`.
The script limits BIND recursion and query-cache access to localhost, so
appliance-network clients get authoritative lab records but cannot use foundry
as a general internet resolver.

The tracked `config/appliance.env.example` keeps the OpenShift appliance
defaults sanitized. Do not commit real pull-secret content, real passwords, or
private lab hostnames.

The tracked `config/operators.env.example` keeps the default mirrored operator
set publishable. Copy it to ignored `config/operators.env` and edit that local
file when the target workshop needs a different catalog, package, or channel
list.

The tracked `config/additional-images.env.example` keeps optional non-operator
image refs publishable. Copy it to ignored `config/additional-images.env` for
IBM Cloud Pak or other private registry image refs that should be mirrored into
`appliance.raw`. The registry credentials for those images must be present in
the pull secret referenced by `APPLIANCE_PULL_SECRET_FILE`. Large image lists
can live in ignored `config/*.images` files referenced by
`APPLIANCE_ADDITIONAL_IMAGES_FILE`.

For a multi-registry pull secret and IBM Cloud Pak examples, see
`docs/registry-auth.md`.

## Run Order

Run these from the repository root on the operator workstation:

```bash
./scripts/06-create-foundry-vm.sh
./scripts/07-configure-foundry-console.sh
./scripts/08-configure-foundry-services.sh
./scripts/09-verify-foundry-services.sh
./scripts/10-prepare-appliance-assets.sh
./scripts/11-build-appliance-image.sh
./scripts/12-create-cluster-config-image.sh
```

`06-create-foundry-vm.sh` creates the VM on the virtualization host.

It does not attach the staged RHEL cloud image directly. It copies that image to
a standalone foundry QCOW2, resizes the copy, then boots it with a NoCloud
cloud-init seed ISO for hostname, SSH key, and network configuration.

The VM uses VNC graphics bound to `127.0.0.1` on the virtualization host. That
keeps the VNC service off the lab networks while still giving Cockpit a
graphical console to proxy.

`07-configure-foundry-console.sh` sets the configured console password on
`appliance` and `cloud-user`. It also keeps `appliance` configured for
passwordless sudo.

`08-configure-foundry-services.sh` reaches foundry through the virtualization
host and configures:

- IdM with integrated DNS for `appliance.workshop.lan`
- foundry-only recursive forwarding for upstream CDN lookups
- NTP service for `172.16.10.0/24`
- web staging directories under `/srv/appliance`
- podman and image-copy tooling for later appliance-builder work
- environment defaults for `APPLIANCE_ASSETS` and `APPLIANCE_IMAGE`

`09-verify-foundry-services.sh` checks the service state and confirms the DNS,
NTP, and web staging endpoints respond.

`10-prepare-appliance-assets.sh` copies the real pull secret into foundry-local
ignored paths and writes generated `appliance-config.yaml`,
`install-config.yaml`, and `agent-config.yaml` under `/srv/appliance`. It reads
the operator package list from ignored `config/operators.env`, falling back to
the tracked example when the local file does not exist. It also reads optional
additional image refs from ignored `config/additional-images.env` and writes
them into the ApplianceConfig `additionalImages` section. Those generated files
may contain secret or environment-specific values and should not be copied into
tracked documentation.

`11-build-appliance-image.sh` runs the OpenShift appliance builder container on
foundry. This can be a long, quiet phase while OpenShift 4.21 release content
and the configured operator set are mirrored into `appliance.raw`. The script
prints filesystem usage before the build, then prints `qemu-img info`, `ls -lh`,
and a completion message for `appliance.raw` when the builder finishes.

`12-create-cluster-config-image.sh` downloads a matching `openshift-install`
binary when needed and creates `agentconfig.noarch.iso` for the three OpenShift
VMs.

After script `15` reports install completion, script
`16-verify-ocp-cluster.sh` verifies the cluster from the operator workstation.
It creates a temporary local API tunnel through the virtualization host, copies
the foundry kubeconfig to a temporary local file, runs `oc` checks with
`--insecure-skip-tls-verify=true` for that local tunnel, prints the cluster
state, and removes the temporary tunnel and kubeconfig.

## OpenShift Appliance Content

Script `10` writes the appliance builder input on foundry. The generated file
contains real pull-secret content, so keep it on foundry and out of tracked
documentation.

The tracked build path targets OpenShift 4.21 and includes these requested
operator capabilities by default:

| Capability | Package entries |
| --- | --- |
| OpenShift Virtualization | `kubevirt-hyperconverged` |
| OpenShift Data Foundation | `odf-operator`, `ocs-operator`, `mcg-operator`, `odf-csi-addons-operator`, `odf-dependencies`, `odf-external-snapshotter-operator`, `odf-prometheus-operator`, `ocs-client-operator`, `recipe`, `rook-ceph-operator`, `cephcsi-operator` |
| NMState | `kubernetes-nmstate-operator` |
| cert-manager | `openshift-cert-manager-operator` |
| Network Observability | `netobserv-operator` |
| Web Terminal | `web-terminal` |
| Quay | `quay-operator` |

Changing the operator set or additional image list changes `appliance.raw`, not
only the Agent Installer config ISO. After editing `config/operators.env` or
`config/additional-images.env`, rerun scripts `10` and `11`. When redeploying
the VMs, run script `13` with `APPLIANCE_REFRESH_BASE_IMAGE=true` so the
virtualization host replaces `appliance-base.qcow2` with the rebuilt image.

## Rebuild Foundry

If foundry needs to be recreated, remove the VM and generated disks first.
Script `06` intentionally refuses to overwrite an existing domain or disk.

Run the cleanup on the virtualization host:

```bash
virsh destroy foundry || true
virsh undefine foundry --nvram --remove-all-storage
rm -rf /var/lib/libvirt/images/foundry-seed
rm -f /var/lib/libvirt/images/foundry.qcow2
rm -f /var/lib/libvirt/images/foundry-seed.iso
```

Adjust the paths if `APPLIANCE_FOUNDRY_NAME` or `APPLIANCE_FOUNDRY_IMAGE_DIR`
are changed from the tracked defaults.
These commands are for the foundry VM only. OpenShift appliance node disks are
managed separately under `/home/libvirt/images/appliance-install`.

Then rerun from the operator workstation:

```bash
./scripts/06-create-foundry-vm.sh
./scripts/07-configure-foundry-console.sh
./scripts/08-configure-foundry-services.sh
./scripts/09-verify-foundry-services.sh
```

## Published DNS Defaults

The tracked defaults match the lab proposal:

| Name | Address |
| --- | --- |
| `foundry.appliance.workshop.lan` | `172.16.10.10` |
| `mirror-registry.appliance.workshop.lan` | `172.16.10.10` |
| `api.appliance.workshop.lan` | `172.16.10.5` |
| `api-int.appliance.workshop.lan` | `172.16.10.5` |
| `*.apps.appliance.workshop.lan` | `172.16.10.7` |
| `ocp-01.appliance.workshop.lan` | `172.16.10.11` |
| `ocp-02.appliance.workshop.lan` | `172.16.10.12` |
| `ocp-03.appliance.workshop.lan` | `172.16.10.13` |

The tracked VM resource defaults for those nodes are:

| Node | vCPU | Memory | Disk |
| --- | ---: | ---: | ---: |
| `ocp-01` | 12 | 32 GiB | 200 GiB |
| `ocp-02` | 12 | 32 GiB | 200 GiB |
| `ocp-03` | 12 | 32 GiB | 200 GiB |

The appliance image requires at least 150 GiB, so the published defaults use
200 GiB for both the appliance image and each OpenShift VM overlay disk. Script
`13` places the OpenShift appliance base image, config ISO, and VM overlays
under `/home/libvirt/images/appliance-install` on the virtualization host by
default. In the latest live run that directory contained
`appliance-base.qcow2`, `agentconfig.noarch.iso`, and node overlays. Treat that
path as a configurable example, not a hard requirement.

Change these in ignored local config if the lab addressing or VM sizing changes.
