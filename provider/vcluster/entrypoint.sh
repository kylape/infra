#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  provider create --name NAME --namespace NAMESPACE
  provider delete --name NAME --namespace NAMESPACE
EOF
}

configure_host_kubeconfig() {
  local token_file=/var/run/secrets/kubernetes.io/serviceaccount/token
  local ca_file=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
  local kubeconfig=/tmp/host-kubeconfig

  [[ -r "$token_file" ]] || { echo "service-account token is unavailable" >&2; exit 1; }
  [[ -r "$ca_file" ]] || { echo "service-account CA is unavailable" >&2; exit 1; }
  [[ -n "${KUBERNETES_SERVICE_HOST:-}" ]] || { echo "in-cluster API is unavailable" >&2; exit 1; }

  kubectl config set-cluster host \
    --server="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT_HTTPS:-443}" \
    --certificate-authority="$ca_file" \
    --embed-certs=true \
    --kubeconfig="$kubeconfig" >/dev/null
  kubectl config set-credentials provider \
    --token="$(<"$token_file")" \
    --kubeconfig="$kubeconfig" >/dev/null
  kubectl config set-context host \
    --cluster=host \
    --user=provider \
    --kubeconfig="$kubeconfig" >/dev/null
  kubectl config use-context host --kubeconfig="$kubeconfig" >/dev/null

  export KUBECONFIG="$kubeconfig"
}

create() {
  local name=$1
  local namespace=$2
  configure_host_kubeconfig
  mkdir -p /outputs

  /usr/local/bin/bootstrap-vcluster "$namespace" "$name" > /outputs/kubeconfig

  printf '%s\n' "$name" > /outputs/cluster-name
}

delete() {
  local name=$1
  local namespace=$2

  configure_host_kubeconfig
  kubectl delete route "$name" \
    --namespace "$namespace" \
    --ignore-not-found
  helm uninstall "$name" \
    --namespace "$namespace" \
    --ignore-not-found \
    --wait
}

[[ $# -gt 0 ]] || { usage; exit 2; }
action=$1
shift

name=
namespace=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) name=${2:?missing value for --name}; shift 2 ;;
    --namespace) namespace=${2:?missing value for --namespace}; shift 2 ;;
    *) echo "unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

[[ -n "$name" && -n "$namespace" ]] || { usage; exit 2; }

case "$action" in
  create) create "$name" "$namespace" ;;
  delete) delete "$name" "$namespace" ;;
  *) echo "unknown action: $action" >&2; usage; exit 2 ;;
esac
