# vCluster platform integration

This repository contains the Infra-side implementation of disposable vCluster
sandboxes. Infra runs on an OpenShift host and submits Argo Workflows that run
the provider image. The initial host flavor is `vcluster-on-pirate`.

## Components in this repository

* `provider/vcluster/` contains the provider image and its create/delete
  entrypoint.
* `chart/infra-server/static/flavors.yaml` registers the user-facing flavor.
* `chart/infra-server/static/workflow-vcluster-on-pirate.yaml` defines the
  Argo lifecycle workflow.
* `chart/infra-server/templates/vcluster/` provisions the Pirate namespace and
  workflow runner RBAC.
* `scripts/deploy/bootstrap-vcluster.sh` is the local Helm/Route bootstrap
  helper and uses the same patched image and OCI chart as the provider.
* `tekton/vcluster-runner/` builds the provider image and publishes its chart
  inputs when the Infra-side provider pipeline is used.

The vCluster image, chart, and CSI behavior are maintained in the vCluster
repository. Keep the image tag and OCI chart version synchronized with the
provider workflow.

## Pirate PoC layout

Infra and Argo are control-plane infrastructure in `infra`. Pirate-hosted
vCluster releases share the pre-provisioned `infra-vclusters-pirate` namespace.
Each Helm release must use a unique short name. The vCluster chart scopes its
StatefulSet, Services, Secrets, service accounts, namespaced RBAC, Routes, and
PVCs by release name.

The workflow runner is separate from the vCluster service account. Its Role is
limited to the shared target namespace. Its ClusterRole contains only the
cluster-scoped RBAC/CRD permissions and read permissions needed to create the
vCluster-generated host access rules, including CSIStorageCapacity discovery.

The static namespace is a PoC compromise because namespace creation is a
cluster-scoped privilege. A future per-cluster vCluster operator should own
namespace creation, per-release RBAC, Helm lifecycle, and status reporting.

## Deployment dependencies

The deployment order is:

1. Publish the vCluster image and matching OCI chart.
2. Publish the Infra server image.
3. Install Argo CRDs/controller/server and the Infra Helm release.
4. Provision the OIDC and Infra configuration Secrets.
5. Expose the Infra Service with an OpenShift Route.
6. Create and destroy a `vcluster-on-pirate` sandbox.

Infra currently initializes OIDC at startup and serves HTTPS from the pod. The
development deployment should use a real OIDC provider and a re-encrypt or
passthrough Route. An anonymous mode or edge termination requires explicit,
development-only backend changes.

## Credential boundary

Credential values belong in cluster Secret stores. The Infra web service should
reference workflow credentials and kubeconfig artifacts without reading or
logging their contents. Prefer projected short-lived target-cluster tokens when
the target identity boundary supports TokenRequest. The long-term design is a
vCluster operator per host cluster so broad remote-cluster credentials are not
held by Infra.

The architecture notes and decision records are maintained in the workspace
scratchpad under `infra-vcluster-platform/`.
