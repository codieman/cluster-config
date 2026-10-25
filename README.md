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
| AI access | `components/ai-access/base` | Read-only `ai-access/ai-cluster-reader` ServiceAccount for AI assistants (see [AI access](#ai-access)) |

All resources carry the `argocd.argoproj.io/sync-options: Delete=false` annotation, so deleting or pruning an
Application never deletes the underlying storage, operators or certificates. The exception is AI access, which is
pruned so that removing it from git revokes the access.

# Prerequisites

* OpenShift GitOps operator installed.
* The `cloudflare-api-token-secret` secret (key `api-token`) in the `cert-manager` namespace. It is not stored in
  git.

# Bootstrap

```
./bootstrap.sh local.sno
```

This applies the overlay and the root Application. After that, Argo CD keeps everything in sync from git.

# AI access

AI assistants get their own identity, `ai-access/ai-cluster-reader`, instead of your admin login. Its
`ai-cluster-reader` ClusterRole is an explicit get/list/watch allowlist; the comment at the top of
`components/ai-access/base/clusterrole.yaml` lists what is left out and why. In short it cannot read Secrets,
ConfigMaps or pod logs, cannot exec, port-forward or proxy into pods or nodes, cannot mint tokens or impersonate,
cannot read RBAC, SCCs, users or OAuth clients, and cannot change anything. Changes go through git and Argo CD.

Mint a kubeconfig for it (run as yourself, logged in as admin; the token expires after the given duration, 8h by
default):

```
./scripts/ai-kubeconfig.sh 8h
```

This writes `~/.config/ai-cluster-reader/kubeconfig`. Point the assistant at that file and block it from reading
your own kubeconfigs. For Claude Code that is `.claude/settings.local.json` in this repo (not committed).

To also allow ConfigMaps and pod logs while troubleshooting, point the `ai-access` Application at
`components/ai-access/overlays/extended`, and back to `base` afterwards.

What it can still see: pod and VM specs, which include any credentials put directly into environment variables or
inline cloud-init `userData` instead of a Secret reference, plus node names, IPs and versions. Keep credentials in
Secrets.

To revoke access immediately, delete the ServiceAccount; every token minted for it stops working:

```
oc delete serviceaccount -n ai-access ai-cluster-reader
```

# Validation

```
./scripts/validate_manifests.sh
```

Requires kustomize (or `oc`); helm is not used.
