#!/usr/bin/env bash
# ==============================================================================
# istio-demo-test.sh
# Script kiểm tra toàn bộ tính năng Istio Service Mesh trong namespace `test`
#
# Services:
#   - product-svc  : httpbin (có retry VirtualService)
#   - order-svc    : httpbin (không retry)
#   - sleep-client : curl client
#
# Yêu cầu: kubectl, istioctl đã cài và có quyền truy cập cluster
# ==============================================================================

set -euo pipefail

NAMESPACE="test"
SLEEP_POD=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

header() { echo -e "\n${BLUE}========== $1 ==========${NC}"; }
ok()     { echo -e "${GREEN}[✅ PASS]${NC} $1"; }
fail()   { echo -e "${RED}[❌ FAIL]${NC} $1"; }
info()   { echo -e "${YELLOW}[ℹ️  INFO]${NC} $1"; }

# ==============================================================================
# 0. Lấy tên Pod của sleep-client
# ==============================================================================
header "0. Lấy Sleep Client Pod"
SLEEP_POD=$(kubectl get pod -n "$NAMESPACE" -l app=sleep-client \
  -o jsonpath='{.items[0].metadata.name}')
info "Sleep pod: $SLEEP_POD"

# ==============================================================================
# 1. Kiểm tra Sidecar Injection
# ==============================================================================
header "1. Sidecar Injection"
info "Checking containers in each pod (expect 2 containers: app + istio-proxy)..."
kubectl get pods -n "$NAMESPACE" \
  -o custom-columns='NAME:.metadata.name,READY:.status.containerStatuses[*].ready,CONTAINERS:.spec.containers[*].name'

# Xác nhận istio-proxy tồn tại
if kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].spec.containers[*].name}' \
   | grep -q "istio-proxy"; then
  ok "Sidecar injection hoạt động — istio-proxy được inject thành công"
else
  fail "Không tìm thấy istio-proxy. Kiểm tra label: kubectl get ns $NAMESPACE --show-labels"
fi

# ==============================================================================
# 2. Kiểm tra mTLS
# ==============================================================================
header "2. mTLS STRICT"
info "Checking PeerAuthentication..."
kubectl get peerauthentication -n "$NAMESPACE"

info "Verify mTLS mode via istioctl (cần quyền admin):"
echo "  istioctl x authz check pod/<product-svc-pod> -n $NAMESPACE"

# Test: plain-text call từ ngoài sidecar phải fail (không thể test trong script này)
info "mTLS đang ở STRICT: mọi call giữa pod → pod đều qua TLS tunnel được Envoy quản lý"

# ==============================================================================
# 3. AuthorizationPolicy — sleep-client → product-svc (ALLOWED)
# ==============================================================================
header "3a. AuthorizationPolicy — sleep → product-svc [EXPECT: 200]"
info "Gọi product-svc/status/200 từ sleep-client..."
HTTP_CODE=$(kubectl exec -n "$NAMESPACE" "$SLEEP_POD" -- \
  curl -s -o /dev/null -w "%{http_code}" \
  --max-time 5 \
  http://product-svc/status/200)

echo "  HTTP Status: $HTTP_CODE"
if [ "$HTTP_CODE" = "200" ]; then
  ok "sleep-client → product-svc: ALLOWED (200) ✅"
else
  fail "sleep-client → product-svc: trả $HTTP_CODE thay vì 200"
fi

# ==============================================================================
# 4. AuthorizationPolicy — sleep-client → order-svc (DENIED)
# ==============================================================================
header "3b. AuthorizationPolicy — sleep → order-svc [EXPECT: 403/Connection refused]"
info "Gọi order-svc/status/200 từ sleep-client (nên bị chặn)..."
HTTP_CODE=$(kubectl exec -n "$NAMESPACE" "$SLEEP_POD" -- \
  curl -s -o /dev/null -w "%{http_code}" \
  --max-time 5 \
  http://order-svc/status/200 || echo "000")

echo "  HTTP Status: $HTTP_CODE"
if [ "$HTTP_CODE" = "403" ] || [ "$HTTP_CODE" = "000" ]; then
  ok "sleep-client → order-svc: DENIED ($HTTP_CODE) ✅ — AuthorizationPolicy hoạt động"
else
  fail "sleep-client → order-svc: trả $HTTP_CODE thay vì 403 (kiểm tra lại policy)"
fi

# ==============================================================================
# 5. Retry Test — product-svc trả 500
# ==============================================================================
header "4. VirtualService Retry (product-svc /status/500)"
info "Cấu hình retry: attempts=3, perTryTimeout=2s, retryOn=5xx"
info "Theo dõi upstream_rq_retry metrics trên istio-proxy..."

echo ""
info "--- Gọi product-svc/status/500 và quan sát ---"
kubectl exec -n "$NAMESPACE" "$SLEEP_POD" -- \
  curl -v --max-time 30 \
  http://product-svc/status/500 2>&1 | grep -E "< HTTP|upstream|retry|attempt" || true

echo ""
info "Kiểm tra Envoy access log để thấy retry:"
PRODUCT_POD=$(kubectl get pod -n "$NAMESPACE" -l app=product-svc \
  -o jsonpath='{.items[0].metadata.name}')
info "Xem log của istio-proxy trên product-svc (sẽ thấy 3-4 entries cho 1 client call):"
kubectl logs -n "$NAMESPACE" "$PRODUCT_POD" -c istio-proxy --tail=20 \
  | grep -E "status=500|GET /status/500" || \
  echo "  (Chưa có log, chờ vài giây và thử lại)"

echo ""
info "Xem upstream retry counter:"
kubectl exec -n "$NAMESPACE" "$SLEEP_POD" -c sleep -- \
  curl -s http://localhost:15000/stats | grep -E "retry|upstream_rq_5xx" 2>/dev/null || true

# ==============================================================================
# 6. Summary
# ==============================================================================
header "5. Summary — Istio Resources"
echo ""
info "PeerAuthentication:"
kubectl get peerauthentication -n "$NAMESPACE"

echo ""
info "AuthorizationPolicies:"
kubectl get authorizationpolicy -n "$NAMESPACE"

echo ""
info "VirtualServices:"
kubectl get virtualservice -n "$NAMESPACE"

echo ""
info "DestinationRules:"
kubectl get destinationrule -n "$NAMESPACE"

echo ""
ok "===== Demo hoàn tất ====="
echo ""
echo "📌 Gợi ý thêm:"
echo "  # Xem Kiali dashboard (traffic graph với mTLS icons)"
echo "  istioctl dashboard kiali"
echo ""
echo "  # Validate Istio config"
echo "  istioctl analyze -n $NAMESPACE"
echo ""
echo "  # Xem chi tiết proxy config của sleep-client"
echo "  istioctl proxy-config cluster -n $NAMESPACE $SLEEP_POD"
echo ""
echo "  # Retry metrics từ Envoy admin API (chạy trong sleep-client pod)"
echo "  kubectl exec -n $NAMESPACE $SLEEP_POD -- curl -s localhost:15000/stats/prometheus | grep upstream_rq_retry"
