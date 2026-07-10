#!/usr/bin/env bash
# print-access-urls.sh
# Reads the plan TSV (produced by resolve-branch-tags.sh) and prints:
#   1. Which ArgoCD applications will be synced
#   2. Full service URLs
#
# TSV column layout:
#   1  service_name   2  branch    3  image_tag
#   4  values_file    5  values_key
set -euo pipefail

PLAN_FILE="${1:-developer-build-plan.tsv}"

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "Plan file not found: $PLAN_FILE" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. Service access URLs
# ---------------------------------------------------------------------------
echo ""
echo "┌──────────────────────────────────────────────────────────────────┐"
echo "│   Service endpoints                                              │"
echo "└──────────────────────────────────────────────────────────────────┘"
echo ""
printf "  %-22s %s\n" "SERVICE" "URL"
printf "  %-22s %s\n" "-------" "---"
printf "  %-22s %s\n" "Storefront" "http://storefront.54.179.218.151.nip.io/"
printf "  %-22s %s\n" "Backoffice" "http://backoffice.54.179.218.151.nip.io/"
printf "  %-22s %s\n" "Swagger" "http://api.54.179.218.151.nip.io/swagger-ui"

echo ""
echo "  NOTE: Wait ~60 s for ArgoCD to finish syncing before testing."
echo "────────────────────────────────────────────────────────────────────"

# ---------------------------------------------------------------------------
# 2. Generate HTML snippet for Jenkins Build Description
# ---------------------------------------------------------------------------
cat << 'EOF' > urls.html
<br/><br/>
<b>Service Endpoints:</b><br/>
<ul>
<li><b>Storefront</b>: <a href="http://storefront.54.179.218.151.nip.io/" target="_blank">http://storefront.54.179.218.151.nip.io/</a></li>
<li><b>Backoffice</b>: <a href="http://backoffice.54.179.218.151.nip.io/" target="_blank">http://backoffice.54.179.218.151.nip.io/</a></li>
<li><b>Swagger</b>: <a href="http://api.54.179.218.151.nip.io/swagger-ui" target="_blank">http://api.54.179.218.151.nip.io/swagger-ui</a></li>
</ul>
EOF
