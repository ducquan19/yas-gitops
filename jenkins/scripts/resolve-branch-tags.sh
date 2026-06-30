#!/usr/bin/env bash
# resolve-branch-tags.sh
# Resolves each service's branch parameter to a Docker image tag, then writes
# a TSV plan file consumed by update-values.sh and print-access-urls.sh.
#
# TSV columns:
#   1  service_name   (display name)
#   2  branch         (normalised branch name)
#   3  image_tag      (commit SHA for feature branches; "main"/"latest" as-is)
#   4  cluster_name
#   5  values_file    (path inside the GitOps repo)
#   6  values_key     (top-level YAML key in the values file)
#   7  argocd_app     (ArgoCD Application name)
#   8  access_host    (Worker node IP)
#   9  node_port      (NodePort number defined in values.yaml)
set -euo pipefail

source_repo_url="${SOURCE_REPO_URL:-https://github.com/ducquan19/yas.git}"
output_file="${1:-developer-build-plan.tsv}"

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
normalize_branch() {
  local branch="${1:-main}"
  branch="${branch#"${branch%%[![:space:]]*}"}"
  branch="${branch%"${branch##*[![:space:]]}"}"
  branch="${branch#refs/heads/}"
  if [[ -z "$branch" ]]; then branch="main"; fi
  printf '%s' "$branch"
}

resolve_tag() {
  local branch="$1"
  if [[ "$branch" == "main" || "$branch" == "latest" ]]; then
    printf '%s' "$branch"
    return
  fi

  local commit
  commit="$(git ls-remote "$source_repo_url" "refs/heads/$branch" | awk '{print $1}')"

  if [[ -z "$commit" ]]; then
    echo "ERROR: Cannot resolve commit SHA for branch '$branch' from $source_repo_url" >&2
    exit 1
  fi

  printf '%s' "$commit"
}

branch_value() {
  local env_name="$1"
  printf '%s' "${!env_name:-main}"
}

# ---------------------------------------------------------------------------
# write_service <display_name> <ENV_VAR> <cluster> <values_file> <yaml_key>
#               <argocd_app> <worker_ip> <node_port>
# ---------------------------------------------------------------------------
write_service() {
  local service_name="$1"
  local branch_env="$2"
  local cluster_name="$3"
  local values_file="$4"
  local values_key="$5"
  local argocd_app="$6"
  local access_host="$7"
  local node_port="$8"

  local branch
  local image_tag

  branch="$(normalize_branch "$(branch_value "$branch_env")")"
  image_tag="$(resolve_tag "$branch")"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$service_name" \
    "$branch" \
    "$image_tag" \
    "$cluster_name" \
    "$values_file" \
    "$values_key" \
    "$argocd_app" \
    "$access_host" \
    "$node_port" >> "$output_file"
}

# ---------------------------------------------------------------------------
# Build the plan – 14 services across 4 clusters
#
# Cluster layout:
#   cluster-2  tbnguyen274  100.84.105.114  → product, inventory, search, media
#   cluster-3  avocado2     100.65.39.31    → cart, order, tax
#   cluster-4  nqthang      100.122.97.48   → storefront, storefront-bff,
#                                             backoffice, backoffice-bff,
#                                             customer, sampledata, swagger
#
# NodePort values must match helm/yas/values.yaml
# ---------------------------------------------------------------------------
printf '' > "$output_file"

# ── cluster-2 : tbnguyen274 ────────────────────────────────────────────────
write_service "product-service"   "PRODUCT_SERVICE_BRANCH"   "cluster-2" "helm/yas/values-tbnguyen274.yaml" "product"   "tbnguyen274" "100.84.105.114" "30005"
write_service "inventory-service" "INVENTORY_SERVICE_BRANCH" "cluster-2" "helm/yas/values-tbnguyen274.yaml" "inventory" "tbnguyen274" "100.84.105.114" "30010"
write_service "search-service"    "SEARCH_SERVICE_BRANCH"    "cluster-2" "helm/yas/values-tbnguyen274.yaml" "search"    "tbnguyen274" "100.84.105.114" "30012"
write_service "media-service"     "MEDIA_SERVICE_BRANCH"     "cluster-2" "helm/yas/values-tbnguyen274.yaml" "media"     "tbnguyen274" "100.84.105.114" "30006"

# ── cluster-3 : avocado2 ──────────────────────────────────────────────────

# ── cluster-4 : nqthang ───────────────────────────────────────────────────
write_service "storefront"     "STOREFRONT_BRANCH"     "cluster-4" "helm/yas/values-nqthang.yaml" "storefront"     "nqthang" "100.122.97.48" "30001"
write_service "storefront-bff" "STOREFRONT_BFF_BRANCH" "cluster-4" "helm/yas/values-nqthang.yaml" "storefront-bff" "nqthang" "100.122.97.48" "30002"
write_service "backoffice"     "BACKOFFICE_BRANCH"     "cluster-4" "helm/yas/values-nqthang.yaml" "backoffice"     "nqthang" "100.122.97.48" "30003"
write_service "backoffice-bff" "BACKOFFICE_BFF_BRANCH" "cluster-4" "helm/yas/values-nqthang.yaml" "backoffice-bff" "nqthang" "100.122.97.48" "30004"
write_service "customer-service" "CUSTOMER_SERVICE_BRANCH" "cluster-4" "helm/yas/values-nqthang.yaml" "customer"  "nqthang" "100.122.97.48" "30007"

# ── cluster-1 : tdquan ───────────────────────────────────────────────────
write_service "cart-service"   "CART_SERVICE_BRANCH"   "cluster-1" "helm/yas/values-tdquan.yaml" "cart"       "tdquan" "100.91.182.4" "30008"
write_service "order-service"  "ORDER_SERVICE_BRANCH"  "cluster-1" "helm/yas/values-tdquan.yaml" "order"      "tdquan" "100.91.182.4" "30009"
write_service "tax-service"    "TAX_SERVICE_BRANCH"    "cluster-1" "helm/yas/values-tdquan.yaml" "tax"        "tdquan" "100.91.182.4" "30011"
write_service "sampledata"     "SAMPLEDATA_BRANCH"     "cluster-1" "helm/yas/values-tdquan.yaml" "sampledata" "tdquan" "100.91.182.4" "30013"
write_service "swagger"        "SWAGGER_BRANCH"        "cluster-1" "helm/yas/values-tdquan.yaml" "swagger"    "tdquan" "100.91.182.4" "30014"

echo "Resolved developer build plan:"
column -t -s $'\t' "$output_file" || cat "$output_file"
