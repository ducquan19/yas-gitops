#!/usr/bin/env bash
set -euo pipefail

values_file="$1"
service_key="$2"

if [[ ! -f "$values_file" ]]; then
  echo "main"
  exit 0
fi

tag=$(awk -v service_key="$service_key" '
  BEGIN { in_service = 0; in_image = 0 }
  /^[A-Za-z0-9_-]+:[[:space:]\r]*$/ {
    # Remove \r if present
    sub(/\r$/, "", $0)
    in_service = ($0 == service_key ":")
    in_image = 0
  }
  in_service && /^[[:space:]]+image:[[:space:]\r]*$/ {
    in_image = 1
  }
  in_service && in_image && /^[[:space:]]+tag:[[:space:]]*/ {
    sub(/^[[:space:]]+tag:[[:space:]]*/, "")
    gsub(/["\047]/, "")
    sub(/\r$/, "", $0)
    print $0
    exit
  }
' "$values_file")

if [[ -z "$tag" ]]; then
  echo "main"
else
  echo "$tag"
fi
