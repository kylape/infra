# Infra vCluster platform

The Pirate proof of concept runs Infra inside a manually provisioned management
vCluster. The management vCluster hosts Argo CD, Argo Workflows, Infra,
Keycloak, and MinIO. Infra manages disposable workload vClusters in the static
host namespace `infra-vclusters-pirate`; it does not manage its own management
vCluster.

The management vCluster uses separate virtual namespaces: `argocd`, `argo`,
`infra`, `object-storage`, `keycloak`, and `default` for workflow objects.
MinIO provides the S3-compatible Argo artifact repository. Infra signs and
reads artifacts through the MinIO API using `MINIO_ENDPOINT`,
`MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`, and `MINIO_SECURE`.

The host OpenShift Route is applied separately and points at the Service
created by vCluster service synchronization. It uses passthrough TLS to the
Infra backend. The Route is therefore a host bootstrap concern and is not
managed by Infra's guest resources.

## Repository locations

* `chart/infra-server/` packages Infra and Argo Workflows.
* `gitops/pirate/minio.yaml` deploys MinIO in the guest `object-storage`
  namespace.
* `chart/infra-server/static/workflow-vcluster-on-pirate.yaml` defines the
  provider workflow.
* `scripts/deploy/bootstrap-vcluster.sh` is the local workload-vCluster
  bootstrap helper.

Confidential Helm values and the MinIO root Secret remain outside Git. The
provider workflow uses constrained RBAC in the pre-created host namespace.
