#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  provider create --name NAME --namespace NAMESPACE [--server SERVER]
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
  local server=${3:-}

  configure_host_kubeconfig
  mkdir -p /outputs

  vcluster create "$name" \
    --namespace "$namespace" \
    --connect=false

  if [[ -n "$server" ]]; then
    vcluster connect "$name" \
      --namespace "$namespace" \
      --server="$server" \
      --print \
      --update-current=false > /outputs/kubeconfig
  else
    vcluster connect "$name" \
      --namespace "$namespace" \
      --print \
      --update-current=false > /outputs/kubeconfig
  fi

  printf '%s\n' "$name" > /outputs/cluster-name
}

delete() {
  local name=$1
  local namespace=$2

  configure_host_kubeconfig
  vcluster delete "$name" \
    --namespace "$namespace" \
    --ignore-not-found
}

[[ $# -gt 0 ]] || { usage; exit 2; }
action=$1
shift

name=
namespace=
server=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) name=${2:?missing value for --name}; shift 2 ;;
    --namespace) namespace=${2:?missing value for --namespace}; shift 2 ;;
    --server) server=${2:?missing value for --server}; shift 2 ;;
    *) echo "unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

[[ -n "$name" && -n "$namespace" ]] || { usage; exit 2; }

case "$action" in
  create) create "$name" "$namespace" "$server" ;;
  delete) delete "$name" "$namespace" ;;
  *) echo "unknown action: $action" >&2; usage; exit 2 ;;
esac
