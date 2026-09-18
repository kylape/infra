#!/usr/bin/env bash

set -euo pipefail

# Provision the vCluster used by the host-bootstrap Tekton pipeline, but keep
# the operation local to the caller's current OpenShift context. The generated
# kubeconfig points at the public passthrough Route rather than the in-cluster
# Service name used by the Tekton workspace.

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "required command not found: $1" >&2
    exit 1
  }
}

require_command kubectl
require_command helm

if [[ $# -ne 2 ]]; then
  echo "usage: $0 HOST_NAMESPACE VCLUSTER_NAME" >&2
  exit 2
fi

HOST_NAMESPACE="$1"
VCLUSTER_NAME="$2"
VCLUSTER_CHART_REPOSITORY="${VCLUSTER_CHART_REPOSITORY:-oci://quay.io/klape/charts/vcluster}"
VCLUSTER_CHART_VERSION="${VCLUSTER_CHART_VERSION:-0.0.1-combined.2}"
VCLUSTER_IMAGE_REGISTRY="${VCLUSTER_IMAGE_REGISTRY:-quay.io}"
VCLUSTER_IMAGE_REPOSITORY="${VCLUSTER_IMAGE_REPOSITORY:-klape/vcluster}"
VCLUSTER_IMAGE_TAG="${VCLUSTER_IMAGE_TAG:-csi-capacity-debug}"
ETCD_IMAGE_REGISTRY="${ETCD_IMAGE_REGISTRY:-registry.k8s.io}"
ETCD_IMAGE_REPOSITORY="${ETCD_IMAGE_REPOSITORY:-etcd}"
ETCD_IMAGE_TAG="${ETCD_IMAGE_TAG:-3.6.8-0}"
KUBECONFIG_SECRET_NAME="${KUBECONFIG_SECRET_NAME:-llm-d-e2e-guest-kubeconfig}"
KUBECONFIG_SECRET_NAMESPACE="${KUBECONFIG_SECRET_NAMESPACE:-klape-llm-d-e2e}"
ROUTE_NAME="${ROUTE_NAME:-${VCLUSTER_NAME}}"

if [[ -z "${ROUTE_HOST:-}" ]]; then
  ROUTE_DOMAIN="$(kubectl get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')"
  if [[ -z "$ROUTE_DOMAIN" ]]; then
    echo "could not determine the OpenShift ingress domain; set ROUTE_HOST" >&2
    exit 1
  fi
  ROUTE_HOST="${ROUTE_NAME}-${HOST_NAMESPACE}.${ROUTE_DOMAIN}"
fi

echo "Creating namespace $HOST_NAMESPACE if needed"
kubectl create namespace "$HOST_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "Installing vCluster $VCLUSTER_NAME in $HOST_NAMESPACE"
chart_dir="$(mktemp -d)"
trap 'rm -rf "$chart_dir" "${tmp_kubeconfig:-}"' EXIT
helm pull "$VCLUSTER_CHART_REPOSITORY" \
  --version "$VCLUSTER_CHART_VERSION" \
  --untar --untardir "$chart_dir"
helm upgrade --install "$VCLUSTER_NAME" "$chart_dir/vcluster" \
  --namespace "$HOST_NAMESPACE" \
  --set controlPlane.statefulSet.security.profile=restricted \
  --set controlPlane.statefulSet.image.registry="$VCLUSTER_IMAGE_REGISTRY" \
  --set controlPlane.statefulSet.image.repository="$VCLUSTER_IMAGE_REPOSITORY" \
  --set controlPlane.statefulSet.image.tag="$VCLUSTER_IMAGE_TAG" \
  --set sync.fromHost.nodes.enabled=true \
  --set sync.toHost.pods.enabled=true \
  --set sync.toHost.gatewayApi.enabled=true \
  --set sync.toHost.gatewayApi.httpRoutes.enabled=true \
  --set sync.toHost.gatewayApi.gateways.enabled=true \
  --set controlPlane.distro.k8s.scheduler.enabled=false \
  --set controlPlane.service.spec.type=ClusterIP \
  --set controlPlane.backingStore.etcd.deploy.enabled=true \
  --set controlPlane.backingStore.etcd.deploy.statefulSet.enabled=true \
  --set controlPlane.backingStore.etcd.deploy.statefulSet.image.registry="$ETCD_IMAGE_REGISTRY" \
  --set controlPlane.backingStore.etcd.deploy.statefulSet.image.repository="$ETCD_IMAGE_REPOSITORY" \
  --set controlPlane.backingStore.etcd.deploy.statefulSet.image.tag="$ETCD_IMAGE_TAG"

kubectl wait --for=condition=Available \
  "deployment/$VCLUSTER_NAME" --namespace "$HOST_NAMESPACE" --timeout=10m

echo "Creating passthrough Route $ROUTE_NAME at $ROUTE_HOST"
cat <<EOF | kubectl apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: $ROUTE_NAME
  namespace: $HOST_NAMESPACE
spec:
  host: $ROUTE_HOST
  to:
    kind: Service
    name: $VCLUSTER_NAME
  port:
    targetPort: 443
  tls:
    termination: passthrough
EOF

if kubectl get secret "$KUBECONFIG_SECRET_NAME" \
  --namespace "$KUBECONFIG_SECRET_NAMESPACE" >/dev/null 2>&1; then
  echo "Keeping existing kubeconfig Secret $KUBECONFIG_SECRET_NAMESPACE/$KUBECONFIG_SECRET_NAME"
  exit 0
fi

echo "Waiting for the vCluster kubeconfig Secret"
kubectl wait --for=create "secret/vc-$VCLUSTER_NAME" \
  --namespace "$HOST_NAMESPACE" --timeout=5m

echo "Generating kubeconfig through https://$ROUTE_HOST"
tmp_kubeconfig="$(mktemp)"
trap 'rm -f "$tmp_kubeconfig"' EXIT
kubectl get secret "vc-$VCLUSTER_NAME" \
  --namespace "$HOST_NAMESPACE" \
  -o jsonpath='{.data.config}' | base64 --decode > "$tmp_kubeconfig"
sed -i -E "s#(^[[:space:]]*server:)[[:space:]]+.*#\1 https://${ROUTE_HOST}#" \
  "$tmp_kubeconfig"

kubectl create namespace "$KUBECONFIG_SECRET_NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic "$KUBECONFIG_SECRET_NAME" \
  --namespace "$KUBECONFIG_SECRET_NAMESPACE" \
  --from-file=config="$tmp_kubeconfig" \
  --type=Opaque

echo "Created $KUBECONFIG_SECRET_NAMESPACE/$KUBECONFIG_SECRET_NAME"
echo "Guest endpoint: https://$ROUTE_HOST"
