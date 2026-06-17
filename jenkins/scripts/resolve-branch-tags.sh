#!/usr/bin/env bash
set -euo pipefail

source_repo_url="${SOURCE_REPO_URL:-https://github.com/ducquan19/yas.git}"
output_file="${1:-developer-build-plan.tsv}"

normalize_branch() {
  local branch="${1:-main}"
  branch="${branch#"${branch%%[![:space:]]*}"}"
  branch="${branch%"${branch##*[![:space:]]}"}"
  branch="${branch#refs/heads/}"

  if [[ -z "$branch" ]]; then
    branch="main"
  fi

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
    echo "Cannot resolve commit id for branch '$branch' from $source_repo_url" >&2
    exit 1
  fi

  printf '%s' "$commit"
}

branch_value() {
  local env_name="$1"
  printf '%s' "${!env_name:-main}"
}

write_service() {
  local service_name="$1"
  local branch_env="$2"
  local cluster_name="$3"
  local values_file="$4"
  local values_key="$5"
  local argocd_app="$6"
  local access_host="$7"

  local branch
  local image_tag

  branch="$(normalize_branch "$(branch_value "$branch_env")")"
  image_tag="$(resolve_tag "$branch")"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$service_name" \
    "$branch" \
    "$image_tag" \
    "$cluster_name" \
    "$values_file" \
    "$values_key" \
    "$argocd_app" \
    "$access_host" >> "$output_file"
}

printf '' > "$output_file"

write_service "postgres" "POSTGRES_BRANCH" "cluster-1" "helm/yas/values-tdquan.yaml" "postgres" "tdquan" "100.91.182.4"
write_service "elasticsearch" "ELASTICSEARCH_BRANCH" "cluster-1" "helm/yas/values-tdquan.yaml" "elasticsearch" "tdquan" "100.91.182.4"
write_service "promotion" "PROMOTION_BRANCH" "cluster-1" "helm/yas/values-tdquan.yaml" "promotion" "tdquan" "100.91.182.4"
write_service "location" "LOCATION_BRANCH" "cluster-1" "helm/yas/values-tdquan.yaml" "location" "tdquan" "100.91.182.4"
write_service "webhook" "WEBHOOK_BRANCH" "cluster-1" "helm/yas/values-tdquan.yaml" "webhook" "tdquan" "100.91.182.4"

write_service "product-service" "PRODUCT_SERVICE_BRANCH" "cluster-2" "helm/yas/values-tbnguyen274.yaml" "product" "tbnguyen274" "100.84.105.114"
write_service "inventory-service" "INVENTORY_SERVICE_BRANCH" "cluster-2" "helm/yas/values-tbnguyen274.yaml" "inventory" "tbnguyen274" "100.84.105.114"
write_service "search-service" "SEARCH_SERVICE_BRANCH" "cluster-2" "helm/yas/values-tbnguyen274.yaml" "search" "tbnguyen274" "100.84.105.114"
write_service "media-service" "MEDIA_SERVICE_BRANCH" "cluster-2" "helm/yas/values-tbnguyen274.yaml" "media" "tbnguyen274" "100.84.105.114"
write_service "recommendation-service" "RECOMMENDATION_SERVICE_BRANCH" "cluster-2" "helm/yas/values-tbnguyen274.yaml" "recommendation" "tbnguyen274" "100.84.105.114"

write_service "cart-service" "CART_SERVICE_BRANCH" "cluster-3" "helm/yas/values-avocado2.yaml" "cart" "avocado2" "100.65.39.31"
write_service "order-service" "ORDER_SERVICE_BRANCH" "cluster-3" "helm/yas/values-avocado2.yaml" "order" "avocado2" "100.65.39.31"
write_service "payment-service" "PAYMENT_SERVICE_BRANCH" "cluster-3" "helm/yas/values-avocado2.yaml" "payment" "avocado2" "100.65.39.31"
write_service "delivery-service" "DELIVERY_SERVICE_BRANCH" "cluster-3" "helm/yas/values-avocado2.yaml" "delivery" "avocado2" "100.65.39.31"
write_service "tax-service" "TAX_SERVICE_BRANCH" "cluster-3" "helm/yas/values-avocado2.yaml" "tax" "avocado2" "100.65.39.31"

write_service "storefront" "STOREFRONT_BRANCH" "cluster-4" "helm/yas/values-nqthang.yaml" "storefront" "nqthang" "100.122.97.48"
write_service "storefront-bff" "STOREFRONT_BFF_BRANCH" "cluster-4" "helm/yas/values-nqthang.yaml" "storefront-bff" "nqthang" "100.122.97.48"
write_service "backoffice" "BACKOFFICE_BRANCH" "cluster-4" "helm/yas/values-nqthang.yaml" "backoffice" "nqthang" "100.122.97.48"
write_service "backoffice-bff" "BACKOFFICE_BFF_BRANCH" "cluster-4" "helm/yas/values-nqthang.yaml" "backoffice-bff" "nqthang" "100.122.97.48"
write_service "customer-service" "CUSTOMER_SERVICE_BRANCH" "cluster-4" "helm/yas/values-nqthang.yaml" "customer" "nqthang" "100.122.97.48"
write_service "identity-service" "IDENTITY_SERVICE_BRANCH" "cluster-4" "helm/yas/values-nqthang.yaml" "identity" "nqthang" "100.122.97.48"
write_service "kafka" "KAFKA_BRANCH" "cluster-4" "helm/yas/values-nqthang.yaml" "kafka" "nqthang" "100.122.97.48"
write_service "rating-service" "RATING_SERVICE_BRANCH" "cluster-4" "helm/yas/values-nqthang.yaml" "rating" "nqthang" "100.122.97.48"

echo "Resolved developer build plan:"
column -t -s $'\t' "$output_file" || cat "$output_file"
