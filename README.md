# GitOps Cluster Configuration

Cluster configuration for the `ocplocal` single-node OpenShift cluster, managed with Argo CD
(OpenShift GitOps). Originally forked from [gnunn-gitops/cluster-config](https://github.com/gnunn-gitops/cluster-config)
and trimmed down to what this cluster needs.

OpenShift Virtualization, NMState and MTV are managed from the
[ocp-vrt](https://github.com/sysmatrix1/ocp-vrt) repository, not here.

# Structure

* _bootstrap/root-app.yaml_ - the `cluster-config` root Application (app of apps), which deploys
  `bootstrap/overlays/local.sno`.
* _bootstrap/overlays/local.sno_ - the `cluster-config` AppProject and one Argo CD Application per component, as
  plain kustomize. To add a component, add an Application to `applications.yaml`.
* _components_ - the kustomize manifests for each component:

| Component | Path | Contents |
|-----------|------|----------|
| LVM Storage | `components/lvm-operator/base` | LVMS operator (`stable-4.22`) and the `local-lvmcluster` LVMCluster backing the default `lvms-vg1` StorageClass |
| cert-manager | `components/cert-manager-operator/aggregate/overlays/letsencrypt` | cert-manager operator, CertManager instance and the `letsencrypt-prod` ClusterIssuer (Cloudflare DNS-01) |
| Certificates | `components/certificates/base` | Let's Encrypt certificates for the API server and the default ingress wildcard |

All resources carry the `argocd.argoproj.io/sync-options: Delete=false` annotation, so deleting or pruning an
Application never deletes the underlying storage, operators or certificates.

# Prerequisites

* OpenShift GitOps operator installed.
* The `cloudflare-api-token-secret` secret (key `api-token`) in the `cert-manager` namespace. It is not stored in
  git.

# Bootstrap

```
./bootstrap.sh local.sno
```

This applies the overlay and the root Application. After that, Argo CD keeps everything in sync from git.

# Validation

```
./scripts/validate_manifests.sh
```

Requires kustomize (or `oc`); helm is not used.
