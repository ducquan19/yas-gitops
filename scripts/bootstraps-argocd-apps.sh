#!/usr/bin/env bash
set -euo pipefail

target_cluster="${TARGET_ARGOCD_CLUSTER:-tdquan}"
argocd_namespace="${ARGOCD_NAMESPACE:-argocd}"

kubeconfig_for_cluster() {
  case "$1" in
    tdquan) printf '%s' "${KUBECONFIG_TDQUAN:?KUBECONFIG_TDQUAN is required}" ;;
    tbnguyen274) printf '%s' "${KUBECONFIG_TBNGUYEN274:?KUBECONFIG_TBNGUYEN274 is required}" ;;
    avocado2) printf '%s' "${KUBECONFIG_AVOCADO2:?KUBECONFIG_AVOCADO2 is required}" ;;
    nqthang) printf '%s' "${KUBECONFIG_NQTHANG:?KUBECONFIG_NQTHANG is required}" ;;
    *)
      echo "Unknown TARGET_ARGOCD_CLUSTER: $1" >&2
      exit 1
      ;;
  esac
}

kubeconfig="$(kubeconfig_for_cluster "$target_cluster")"

echo "Applying ArgoCD project and applications into ${target_cluster}/${argocd_namespace}"
kubectl --kubeconfig "$kubeconfig" get namespace "$argocd_namespace"
kubectl --kubeconfig "$kubeconfig" apply -f argocd/project.yaml
kubectl --kubeconfig "$kubeconfig" apply -f argocd/applications/

echo ""
echo "ArgoCD Applications:"
kubectl --kubeconfig "$kubeconfig" -n "$argocd_namespace" get applications.argoproj.io
