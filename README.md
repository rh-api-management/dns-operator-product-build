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
