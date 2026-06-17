#!/usr/bin/env bash
set -euo pipefail

plan_file="${1:-developer-build-plan.tsv}"

if [[ ! -f "$plan_file" ]]; then
  echo "Plan file not found: $plan_file" >&2
  exit 1
fi

echo "ArgoCD applications that may sync after GitOps push:"
awk -F '\t' '
  {
    key = $7 "\t" $5
    if (!seen_app[key]++) {
      print "- " $7 ": " $5
    }
  }
' "$plan_file"

echo ""
echo "Access hints after ArgoCD sync:"
awk -F '\t' '
  {
    key = $4 "\t" $8
    if (!seen_cluster[key]++) {
      print "- " $4 ": http://" $8 ":<NodePort>"
    }
  }
' "$plan_file"
