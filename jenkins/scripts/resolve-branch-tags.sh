#!/usr/bin/env bash
# resolve-branch-tags.sh
# Resolves each service's branch parameter to a Docker image tag, then writes
# a TSV plan file consumed by update-values.sh and print-access-urls.sh.
#
# TSV columns:
#   1  service_name   (display name)
#   2  branch         (normalised branch name)
#   3  image_tag      (commit SHA for feature branches; "main"/"latest" as-is)
#   4  values_file    (path inside the GitOps repo)
#   5  values_key     (top-level YAML key in the values file)
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
  local values_file="$2"
  local values_key="$3"

  if [[ "$branch" == "main" ]]; then
    # Read the existing stable tag from the file
    bash jenkins/scripts/get-stable-tag.sh "$values_file" "$values_key"
    return
  elif [[ "$branch" == "latest" ]]; then
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
# write_service <display_name> <ENV_VAR> <values_file> <yaml_key>
# ---------------------------------------------------------------------------
write_service() {
  local service_name="$1"
  local branch_env="$2"
  local values_file="$3"
  local values_key="$4"

  local branch
  local image_tag

  branch="$(normalize_branch "$(branch_value "$branch_env")")"
  
  # Only process and update services that have a custom branch specified
  if [[ "$branch" == "main" ]]; then
    return
  fi

  image_tag="$(resolve_tag "$branch" "$values_file" "$values_key")"

  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$service_name" \
    "$branch" \
    "$image_tag" \
    "$values_file" \
    "$values_key" >> "$output_file"
}

# ---------------------------------------------------------------------------
# Build the plan – 14 services across 4 clusters
#
# Cluster layout:
#   cluster-1  tdquan       100.91.182.4    → product, cart, order, inventory, tax, customer, media, search, sampledata, storefront-bff, backoffice-bff
#   cluster-2  tbnguyen274  100.84.105.114  → (standby)
#   cluster-3  avocado2     100.65.39.31    → (standby)
#   cluster-4  nqthang      100.122.97.48   → storefront, backoffice, swagger
#
# NodePort values must match helm/yas/values.yaml
# ---------------------------------------------------------------------------
printf '' > "$output_file"

write_service "storefront"      "STOREFRONT_BRANCH"       "helm/yas/values.yaml" "storefront-nextjs"
write_service "storefront-bff"  "STOREFRONT_BFF_BRANCH"   "helm/yas/values.yaml" "storefront-bff"
write_service "backoffice"      "BACKOFFICE_BRANCH"       "helm/yas/values.yaml" "backoffice-nextjs"
write_service "backoffice-bff"  "BACKOFFICE_BFF_BRANCH"   "helm/yas/values.yaml" "backoffice-bff"
write_service "product-service" "PRODUCT_SERVICE_BRANCH"  "helm/yas/values.yaml" "product"
write_service "media-service"   "MEDIA_SERVICE_BRANCH"    "helm/yas/values.yaml" "media"
write_service "customer-service" "CUSTOMER_SERVICE_BRANCH" "helm/yas/values.yaml" "customer"
write_service "cart-service"    "CART_SERVICE_BRANCH"     "helm/yas/values.yaml" "cart"
write_service "order-service"   "ORDER_SERVICE_BRANCH"    "helm/yas/values.yaml" "order"
write_service "inventory-service" "INVENTORY_SERVICE_BRANCH" "helm/yas/values.yaml" "inventory"
write_service "tax-service"     "TAX_SERVICE_BRANCH"      "helm/yas/values.yaml" "tax"
write_service "search-service"  "SEARCH_SERVICE_BRANCH"   "helm/yas/values.yaml" "search"
write_service "sampledata"      "SAMPLEDATA_BRANCH"       "helm/yas/values.yaml" "sampledata"
write_service "swagger"         "SWAGGER_BRANCH"          "helm/yas/values.yaml" "swagger"

echo "Resolved developer build plan:"
column -t -s $'\t' "$output_file" || cat "$output_file"
