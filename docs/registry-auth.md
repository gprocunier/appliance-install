# Registry Auth Examples

The appliance builder uses the pull secret referenced by
`APPLIANCE_PULL_SECRET_FILE` in ignored `config/appliance.env`. That pull secret
must include credentials for every private registry named in
`config/operators.env`, `config/additional-images.env`, or an additional
`config/*.images` list.

## Example Files

Copy the tracked examples to ignored local files before editing real values:

```bash
#### Create ignored registry auth and IBM content examples

cp config/pull-secret.multi-registry.json.example \
    config/pull-secret.multi-registry.json

cp config/operators.ibm-cloudpak.env.example \
    config/operators.env

cp config/additional-images.ibm-cloudpak.env.example \
    config/additional-images.env

cp config/cloudpak.images.example \
    config/cloudpak.images
```

Then point `config/appliance.env` at the ignored pull secret file with an
absolute path:

```bash
APPLIANCE_PULL_SECRET_FILE="/absolute/path/to/appliance-install/config/pull-secret.multi-registry.json"
```

## Registry Types

| Registry content | Where the image refs go | Pull secret auth key |
| --- | --- | --- |
| OpenShift release and Red Hat operators | Existing OpenShift pull secret and `config/operators.env` | `registry.redhat.io`, `registry.connect.redhat.com`, `quay.io` |
| IBM Cloud Pak private operands | `config/additional-images.env` or `config/cloudpak.images` | `cp.icr.io` |
| IBM Cloud Pak public catalogs or helper images | `config/operators.env` or `config/additional-images.env` | `icr.io` when auth is required |
| Private Quay content | `config/operators.env` or `config/additional-images.env` | `quay.io` |
| Generic private registry content | `config/operators.env` or `config/additional-images.env` | `private-registry.example.com:5000` |

For IBM Entitled Registry content, the pull-secret username is commonly `cp`
and the password is the IBM entitlement key. The JSON `auth` value is the
base64 form of `username:password`. Use the exact registry, catalog image,
package, channel, and image list from the IBM release documentation for the
Cloud Pak being demonstrated.

You can also let container tooling write the real auth entries instead of
editing base64 values by hand:

```bash
#### Populate the ignored pull secret with registry logins

podman login --authfile config/pull-secret.multi-registry.json registry.redhat.io
podman login --authfile config/pull-secret.multi-registry.json quay.io
podman login --authfile config/pull-secret.multi-registry.json cp.icr.io
podman login --authfile config/pull-secret.multi-registry.json private-registry.example.com:5000
```

## Build Flow

After changing registry auth or mirrored content, regenerate the appliance
inputs, rebuild `appliance.raw`, then refresh the VM base image:

```bash
./scripts/10-prepare-appliance-assets.sh
./scripts/11-build-appliance-image.sh
APPLIANCE_REFRESH_BASE_IMAGE=true ./scripts/13-create-ocp-vms.sh
```
