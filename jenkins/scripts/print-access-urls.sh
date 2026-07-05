#!/usr/bin/env bash
# print-access-urls.sh
# Reads the plan TSV (produced by resolve-branch-tags.sh) and prints:
#   1. Which ArgoCD applications will be synced
#   2. Full service URLs  →  http://<worker-ip>:<NodePort>
#   3. /etc/hosts entries the developer needs to add
#
# TSV column layout:
#   1  service_name   2  branch    3  image_tag   4  cluster_name
#   5  values_file    6  values_key  7  argocd_app  8  access_host
#   9  node_port
set -euo pipefail

PLAN_FILE="${1:-developer-build-plan.tsv}"

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "Plan file not found: $PLAN_FILE" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. ArgoCD applications
# ---------------------------------------------------------------------------
echo ""
echo "┌──────────────────────────────────────────────────────────────────┐"
echo "│          ArgoCD applications that will be synced                 │"
echo "└──────────────────────────────────────────────────────────────────┘"
awk -F '\t' '
  {
    key = $7 "\t" $5
    if (!seen_app[key]++) {
      printf "  %-20s  →  %s\n", $7, $5
    }
  }
' "$PLAN_FILE"

# ---------------------------------------------------------------------------
# 2. Service access URLs
# ---------------------------------------------------------------------------
echo ""
echo "┌──────────────────────────────────────────────────────────────────┐"
echo "│   Service endpoints  (http://WORKER_IP:NodePort)                 │"
echo "│   Add the hosts entries below so domain names resolve locally.   │"
echo "└──────────────────────────────────────────────────────────────────┘"
echo ""
printf "  %-22s %-10s %-22s %s\n" "SERVICE" "CLUSTER" "IMAGE TAG" "URL"
printf "  %-22s %-10s %-22s %s\n" "-------" "-------" "---------" "---"

while IFS=$'\t' read -r svc_name branch image_tag cluster_name values_file \
                         values_key argocd_app access_host node_port; do
  [[ -z "${svc_name:-}" ]] && continue

  if [[ -n "${node_port:-}" ]]; then
    url="http://${access_host}:${node_port}"
  else
    url="http://${access_host}:<NodePort>"
  fi

  # Truncate long SHA tags for readability
  short_tag="${image_tag:0:12}"
  [[ "${#image_tag}" -gt 12 ]] && short_tag="${short_tag}…"

  printf "  %-22s %-10s %-22s %s\n" "$svc_name" "$cluster_name" "$short_tag" "$url"
done < "$PLAN_FILE"

# ---------------------------------------------------------------------------
# 3. /etc/hosts hint
# ---------------------------------------------------------------------------
echo ""
echo "┌──────────────────────────────────────────────────────────────────┐"
echo "│   Add to your hosts file (if not already present)               │"
echo "│   Windows : C:\\Windows\\System32\\drivers\\etc\\hosts              │"
echo "│   Linux   : /etc/hosts                                           │"
echo "└──────────────────────────────────────────────────────────────────┘"
awk -F '\t' '
  {
    key = $4 "\t" $8
    if (!seen[key]++) {
      printf "  %-18s  yas.%s.local\n", $8, $4
    }
  }
' "$PLAN_FILE"

echo ""
echo "  Example:  echo '100.91.182.4  yas.cluster-1.local' >> /etc/hosts"
echo "  Then open:  http://yas.cluster-1.local:30011  (tax-service)"
echo ""
echo "  NOTE: Wait ~60 s for ArgoCD to finish syncing before testing."
echo "────────────────────────────────────────────────────────────────────"

# ---------------------------------------------------------------------------
# 4. Generate HTML snippet for Jenkins Build Description
# ---------------------------------------------------------------------------
cat << 'EOF' > urls.html
<br/><br/>
<b>Service Endpoints:</b><br/>
<ul>
EOF

while IFS=$'\t' read -r svc_name branch image_tag cluster_name values_file \
                         values_key argocd_app access_host node_port; do
  [[ -z "${svc_name:-}" ]] && continue

  if [[ -n "${node_port:-}" ]]; then
    url="http://${access_host}:${node_port}"
  else
    url="http://${access_host}:&lt;NodePort&gt;"
  fi

  echo "<li><b>${svc_name}</b>: <a href=\"${url}\" target=\"_blank\">${url}</a></li>" >> urls.html
done < "$PLAN_FILE"

echo "</ul>" >> urls.html
