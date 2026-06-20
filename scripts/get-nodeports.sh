#!/usr/bin/env bash
set -euo pipefail

target_env="${1:-all}"

case "$target_env" in
  dev|staging|all)
    ;;
  *)
    echo "TARGET_ENV must be dev, staging, or all." >&2
    exit 1
    ;;
esac

namespace_for_env() {
  case "$1" in
    dev) printf '%s' "yas-dev" ;;
    staging) printf '%s' "yas-staging" ;;
  esac
}

print_nodeports_for_namespace() {
  local cluster_name="$1"
  local kubeconfig="$2"
  local access_host="$3"
  local env_name="$4"
  local namespace

  namespace="$(namespace_for_env "$env_name")"

  echo ""
  echo "== ${cluster_name} / ${namespace} =="

  if ! kubectl --kubeconfig "$kubeconfig" get namespace "$namespace" >/dev/null 2>&1; then
    echo "Namespace ${namespace} does not exist."
    return
  fi

  kubectl --kubeconfig "$kubeconfig" -n "$namespace" get svc \
    -o jsonpath='{range .items[?(@.spec.type=="NodePort")]}{.metadata.name}{"\t"}{range .spec.ports[*]}{.nodePort}{" "}{end}{"\n"}{end}' |
  while IFS=$'\t' read -r service_name node_ports; do
    [[ -z "${service_name:-}" ]] && continue
    for node_port in $node_ports; do
      echo "- ${service_name}: http://${access_host}:${node_port}"
    done
  done
}

print_nodeports_for_cluster() {
  local cluster_name="$1"
  local kubeconfig="$2"
  local access_host="$3"

  if [[ -z "${kubeconfig:-}" || ! -f "$kubeconfig" ]]; then
    echo "Missing kubeconfig for ${cluster_name}" >&2
    exit 1
  fi

  if [[ "$target_env" == "all" ]]; then
    print_nodeports_for_namespace "$cluster_name" "$kubeconfig" "$access_host" dev
    print_nodeports_for_namespace "$cluster_name" "$kubeconfig" "$access_host" staging
  else
    print_nodeports_for_namespace "$cluster_name" "$kubeconfig" "$access_host" "$target_env"
  fi
}

print_nodeports_for_cluster "tdquan" "$KUBECONFIG_TDQUAN" "100.91.182.4"
print_nodeports_for_cluster "tbnguyen274" "$KUBECONFIG_TBNGUYEN274" "100.84.105.114"
print_nodeports_for_cluster "avocado2" "$KUBECONFIG_AVOCADO2" "100.65.39.31"
print_nodeports_for_cluster "nqthang" "$KUBECONFIG_NQTHANG" "100.122.97.48"
