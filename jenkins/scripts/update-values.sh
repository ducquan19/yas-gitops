#!/usr/bin/env bash
set -euo pipefail

plan_file="${1:-developer-build-plan.tsv}"

if [[ ! -f "$plan_file" ]]; then
  echo "Plan file not found: $plan_file" >&2
  exit 1
fi

update_tag() {
  local values_file="$1"
  local service_key="$2"
  local image_tag="$3"
  local temp_file

  if [[ ! -f "$values_file" ]]; then
    echo "Values file not found: $values_file" >&2
    exit 1
  fi

  temp_file="$(mktemp)"

  awk -v service_key="$service_key" -v image_tag="$image_tag" '
    BEGIN {
      in_service = 0
      in_image = 0
      updated = 0
    }
    /^[A-Za-z0-9_-]+:[[:space:]]*$/ {
      in_service = ($0 == service_key ":")
      in_image = 0
    }
    in_service && /^[[:space:]]+image:[[:space:]]*$/ {
      in_image = 1
    }
    in_service && in_image && /^[[:space:]]+tag:[[:space:]]*/ {
      sub(/tag:[[:space:]].*/, "tag: " image_tag)
      updated = 1
    }
    { print }
    END {
      if (!updated) {
        exit 42
      }
    }
  ' "$values_file" > "$temp_file" || {
    rm -f "$temp_file"
    echo "Cannot update ${service_key}.image.tag in ${values_file}" >&2
    exit 1
  }

  mv "$temp_file" "$values_file"
}

while IFS=$'\t' read -r service_name branch image_tag cluster_name values_file values_key argocd_app access_host node_port; do
  [[ -z "${service_name:-}" ]] && continue
  echo "Updating ${values_file}: ${values_key}.image.tag=${image_tag} (${service_name}, branch=${branch})"
  update_tag "$values_file" "$values_key" "$image_tag"
done < "$plan_file"

echo "GitOps values diff:"
git diff -- helm/yas/values-*.yaml || true
