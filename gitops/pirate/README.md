# Pirate management vCluster deployment

This directory contains the GitOps inputs for the Infra management vCluster
running on Pirate OpenShift. The management vCluster is provisioned manually;
Argo CD and Argo Workflows run inside it, while the host cluster only carries
the vCluster workload and the externally applied OpenShift Route.

## Components managed inside the vCluster

* `infra` deploys the Infra server into the `infra` virtual namespace.
* `minio.yaml` deploys MinIO into `object-storage`.
* Argo Workflows uses MinIO as its S3-compatible artifact repository.
* Workflows run in the `default` virtual namespace unless a workflow selects
  another namespace.

Create the `minio-root-credentials` Secret in `object-storage` before syncing
`minio.yaml`. Its `accesskey` and `secretkey` values must match the confidential
Helm values `minio_access_key` and `minio_secret_key`.

Create the `infra-server-oidc` Secret in `infra` before syncing the Application.
It must contain an `oidc.yaml` key. Generate a long random `sessionSecret` and
keep the file outside Git:

```yaml
issuer: https://accounts.google.com
clientID: <registered-client-id>
clientSecret: <registered-client-secret>
endpoint: <Infra UI hostname>
sessionSecret: <at-least-32-byte-random-value>
accessTokenClaims: []
tokenLifetime: 1h
```

```bash
kubectl create secret generic infra-server-oidc \
  --namespace infra \
  --from-file=oidc.yaml=oidc.yaml
```

The Helm chart mounts this Secret into the Infra server without copying its
contents into rendered Helm values. A secret delivery controller can replace
this one-time bootstrap step later.

Create the Keycloak administrator Secret before syncing the Application:

```bash
kubectl create namespace keycloak
kubectl create secret generic keycloak-admin \
  --namespace keycloak \
  --from-literal=username=admin \
  --from-literal=password='<random-password>'
```

Keycloak is deployed in development mode with ephemeral storage for this PoC.
After the pod is ready, bootstrap the `infra` realm, its confidential `infra`
client, and the `developer` user with `kcadm.sh`. The Keycloak Route is
`https://keycloak-infra-vcluster-infra.apps.openshift.nm.rdu4.corp.redhat.com`.

Because the Keycloak Route uses edge TLS termination, copy the OpenShift
ingress CA into the vCluster as `infra-oidc-ca` with a `tls.crt` key. The
Infra chart mounts that CA and uses it to validate the OIDC discovery endpoint.

The host OpenShift Route is applied separately after vCluster service
synchronization exposes the Infra Service in the management vCluster's host
namespace. The Route uses passthrough TLS to the Infra service.
