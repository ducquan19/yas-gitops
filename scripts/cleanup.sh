#!/usr/bin/env bash
set -euo pipefail

target_env="${1:-dev}"
target_cluster="${2:-all}"
cleanup_mode="${3:-delete-failed-pods}"
dry_run="${4:-true}"

case "$target_env" in
  dev|staging)
    namespace="yas-${target_env}"
    ;;
  *)
    echo "TARGET_ENV phải là dev hoặc staging." >&2
    exit 1
    ;;
esac

case "$target_cluster" in
  all|tdquan|tbnguyen274|avocado2|nqthang)
    ;;
  *)
    echo "TARGET_CLUSTER không hợp lệ: ${target_cluster}" >&2
    exit 1
    ;;
esac

case "$cleanup_mode" in
  delete-namespace|delete-failed-pods)
    ;;
  *)
    echo "CLEANUP_MODE phải là delete-namespace hoặc delete-failed-pods." >&2
    exit 1
    ;;
esac

case "$dry_run" in
  true|false)
    ;;
  *)
    echo "DRY_RUN phải là true hoặc false." >&2
    exit 1
    ;;
esac

run_for_cluster() {
  local cluster_name="$1"
  local kubeconfig="$2"

  if [[ "$target_cluster" != "all" && "$target_cluster" != "$cluster_name" ]]; then
    return
  fi

  if [[ -z "${kubeconfig:-}" || ! -f "$kubeconfig" ]]; then
    echo "Không tìm thấy kubeconfig của ${cluster_name}." >&2
    exit 1
  fi

  echo ""
  echo "== ${cleanup_mode}: ${cluster_name} / ${namespace} =="

  if ! kubectl --kubeconfig "$kubeconfig" version --request-timeout=10s >/dev/null 2>&1; then
    echo "Không thể kết nối tới cluster ${cluster_name}." >&2
    exit 1
  fi

  if ! kubectl --kubeconfig "$kubeconfig" get namespace "$namespace" >/dev/null 2>&1; then
    echo "Namespace ${namespace} không tồn tại. Bỏ qua."
    return
  fi

  case "$cleanup_mode" in
    delete-namespace)
      echo "Namespace sẽ bị xóa:"
      kubectl --kubeconfig "$kubeconfig" get namespace "$namespace"

      if [[ "$dry_run" == "false" ]]; then
        kubectl --kubeconfig "$kubeconfig" delete namespace "$namespace" \
          --ignore-not-found=true \
          --wait=true \
          --timeout=180s
      else
        echo "[DRY RUN] Chưa xóa namespace ${namespace}."
      fi
      ;;
    delete-failed-pods)
      echo "Các pod Failed sẽ bị xóa:"
      kubectl --kubeconfig "$kubeconfig" -n "$namespace" get pods \
        --field-selector=status.phase=Failed \
        -o wide

      if [[ "$dry_run" == "false" ]]; then
        kubectl --kubeconfig "$kubeconfig" -n "$namespace" delete pod \
          --field-selector=status.phase=Failed \
          --ignore-not-found=true
      else
        echo "[DRY RUN] Chưa xóa pod Failed trong ${namespace}."
      fi
      ;;
  esac

  echo "Trạng thái sau cleanup:"
  kubectl --kubeconfig "$kubeconfig" get namespace "$namespace" || true

  if [[ "$cleanup_mode" == "delete-failed-pods" ]]; then
    kubectl --kubeconfig "$kubeconfig" -n "$namespace" get pods -o wide || true
  fi
}

run_for_cluster "tdquan" "${KUBECONFIG_TDQUAN:-}"
run_for_cluster "tbnguyen274" "${KUBECONFIG_TBNGUYEN274:-}"
run_for_cluster "avocado2" "${KUBECONFIG_AVOCADO2:-}"
run_for_cluster "nqthang" "${KUBECONFIG_NQTHANG:-}"
