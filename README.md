# DNS Operator Product Build
Konflux build configuration for the DNS Operator component.

## Updating CoreDNS Manifests

The `coredns/manifests/` directory contains pre-generated Kubernetes manifests for deploying CoreDNS with the Kuadrant plugin. These are included in the bundle images at `/coredns/`.

### Structure

```
coredns/
├── base/                    # Base kustomization with common configuration
│   ├── kustomization.yaml
│   └── Corefile
├── overlays/                # Environment-specific image overrides
│   ├── dev/                 # quay.io/redhat-user-workloads/...
│   ├── stage/               # registry.stage.redhat.io/...
│   └── prod/                # registry.redhat.io/...
└── manifests/               # Pre-generated manifests (copied to bundles)
    ├── dev/
    ├── stage/
    └── prod/
```

The base kustomization (`coredns/base/kustomization.yaml`) wraps the upstream `dns-operator/config/coredns-unmonitored` configuration and applies common rhcl specific configuration updates.

Each overlay adds the environment-specific image:
- **dev**: `quay.io/redhat-user-workloads/api-management-tenant/rhcl-1-3-coredns:v1.3.0`
- **stage**: `registry.stage.redhat.io/rhcl-1/coredns-rhel9:v1.3.0`
- **prod**: `registry.redhat.io/rhcl-1/coredns-rhel9:v1.3.0`

### Regenerating Manifests

To regenerate the manifests after updating the dns-operator submodule:

```bash
# Regenerate manifests for all environments (requires kustomize and helm)
kustomize build --enable-helm coredns/overlays/dev > coredns/manifests/dev/manifests.yaml
kustomize build --enable-helm coredns/overlays/stage > coredns/manifests/stage/manifests.yaml
kustomize build --enable-helm coredns/overlays/prod > coredns/manifests/prod/manifests.yaml
```

### Requirements

- [kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/) v5.0+
- [helm](https://helm.sh/docs/intro/install/) v3.0+
## Renovate Configuration

This repository uses [Renovate](https://docs.renovatebot.com/) to automatically manage dependency updates.

### Enabled Managers

The `renovate.json` configuration uses the `enabledManagers` option to explicitly control which package managers are active. This is important because `enabledManagers` is **not additive** - it completely overrides the default manager list.

Currently enabled managers:
- **tekton** - Updates Tekton bundle references in `.tekton/*.yaml` files (e.g., `quay.io/konflux-ci/tekton-catalog/task-*@sha256:...`)
- **dockerfile** - Updates container image references in Dockerfiles and similar files
- **regex** - Custom pattern matching for specialized dependency updates
- **rpm** - Updates RPM package versions in `rpms.in.yaml` and `rpms.lock.yaml` lockfiles
- **github-actions** - Updates GitHub Actions versions in workflow files (`.github/workflows/*.yaml`)

### Excluding Managers

The git-submodules manager is explicitly excluded by omitting it from the `enabledManagers` array. This is intentional because **git submodule updates are managed by our custom GitHub Action** (`.github/workflows/submodule-version-bump.yaml`) rather than by Renovate. This prevents conflicts between the two automation systems.

If you need to add or remove managers, update the `enabledManagers` list in `renovate.json`:

```json
{
  "enabledManagers": ["tekton", "dockerfile", "regex", "rpm", "github-actions"]
}
```

**Note:** When modifying `enabledManagers`, you must list ALL desired managers. Adding one manager without listing the others will disable those others.