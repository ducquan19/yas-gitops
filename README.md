# YAS GitOps Deployment Guide

Kho lưu trữ này chứa toàn bộ cấu hình GitOps (thông qua **ArgoCD**) và **Helm Chart** để triển khai hệ thống vi dịch vụ YAS trên môi trường Đa Cụm (Multi-cluster) kết nối qua **Tailscale**.

## 1. Kiến trúc Hệ Thống
Hệ thống được chia làm 2 phân hệ và triển khai trên 2 cụm Kubernetes riêng biệt, được nối mạng phẳng thông qua **Tailscale**:
- **Cụm `nqthang` (Frontend):** Chạy các ứng dụng giao diện Next.js (`storefront-nextjs`, `backoffice-nextjs`) và `swagger`.
- **Cụm `tdquan` (Backend):** Chạy toàn bộ các vi dịch vụ xử lý logic (`product`, `cart`, `order`, v.v.), các BFF (`storefront-bff`, `backoffice-bff`), và các dịch vụ nền tảng (Database, Keycloak, Kafka, Redis, Elasticsearch).

> Giao tiếp giữa 2 cụm (ví dụ Next.js gọi BFF) được thực hiện trực tiếp nhờ mạng Tailscale. Spring Cloud Gateway trên các BFF đã được cấu hình qua ConfigMap (`yas-gateway-routes-config`) để định tuyến trực tiếp đến các services backend.

## 2. Chuẩn bị trước khi Deploy
Trước khi ArgoCD tiến hành sync, vì biểu đồ Helm của chúng ta phụ thuộc vào các biểu đồ bên thứ 3 (PostgreSQL, Keycloak, Kafka, Redis, Elasticsearch) của Bitnami, bạn cần chắc chắn rằng ArgoCD có thể tải về các Sub-charts này.

Cách đơn giản nhất là tải chúng cục bộ và commit thư mục `charts/` (tuỳ chọn tuỳ thuộc vào cấu hình ArgoCD của bạn):
```bash
cd helm/yas
helm dependency update
```

## 3. Kiến trúc Cấu Hình GitOps YAS
Để tối ưu hóa việc quản lý resource qua ArgoCD, chúng tôi sử dụng mô hình **App of Apps** và chia tách thành 3 biểu đồ chính:

1. **Infrastructure (`helm/infra`)**:
   - Chứa toàn bộ các nền tảng hạ tầng (Kafka, PostgreSQL, Keycloak, Redis, Elasticsearch).
   - Được triển khai vào namespace `infra`.
   - Rất ít khi thay đổi, Deploy 1 lần và chạy nền.

2. **Observability (`helm/observability`)**:
   - Chứa công cụ giám sát (Kiali, Prometheus, Grafana, Loki, Tempo...).
   - Được triển khai vào namespace `observability`.

3. **Applications (`helm/yas`)**:
   - Chỉ chứa các Microservices do team tự phát triển (Product, Cart, Order, Frontend...).
   - Được ArgoCD tự động Sync liên tục khi code thay đổi.
   - Các file config sẽ tự động trỏ kết nối sang DB và Kafka ở namespace `infra`.

## 4. Cách Deploy với ArgoCD
Quy trình triển khai trên ArgoCD (bắt buộc phải theo đúng thứ tự):
1. Khởi tạo và Apply Application cho **Hạ tầng**:
   ```bash
   kubectl apply -f argocd/applications/tdquan-infra.yaml
   ```
   *(Chờ cho Kafka, DB khởi động lên đầy đủ trạng thái Running).*
2. Apply Application cho **Hệ thống giám sát (Observability)**:
   ```bash
   kubectl apply -f argocd/applications/tdquan-observability.yaml
   ```
3. Apply Application cho **YAS Backend (Microservices)**:
   ```bash
   kubectl apply -f argocd/applications/tdquan-staging.yaml
   ```

## 5. Triển khai Local (Không dùng ArgoCD)
Nếu bạn muốn test thử trên máy cá nhân (minikube, docker desktop, kind) mà chưa cần cài ArgoCD, bạn có thể dùng trực tiếp lệnh `helm install`.

Lưu ý: Bạn có thể gộp file `values-tdquan.yaml` (Backend) và `values-nqthang.yaml` (Frontend) lại thành một để chạy chung trên 1 cụm cục bộ!

```bash
# 1. Cài đặt các dependencies cho YAS chart
cd helm/yas
helm dependency update

# 2. Deploy YAS stack (cả frontend và backend chung 1 namespace)
kubectl create namespace yas-local
helm install yas-local . -n yas-local -f values-tdquan.yaml -f values-nqthang.yaml

# 3. Deploy Observability stack
cd ../observability
helm dependency update
kubectl create namespace observability
helm install observability . -n observability
```

## 5. Các cấu hình Hệ Thống Quan Trọng Cần Lưu Ý
Sau khi các Pods đã lên trạng thái `Running`, bạn cần lưu ý:

- **Database (PostgreSQL):** Bạn **KHÔNG CẦN LÀM GÌ CẢ**! PostgreSQL đã được nhúng sẵn kịch bản khởi tạo (`init-databases.sql`) trong `values.yaml`. Khi khởi động lần đầu, nó sẽ tự động tạo toàn bộ 14 databases (product, cart, customer, v.v.). Sau đó, **Flyway** bên trong các dịch vụ Spring Boot sẽ tự động chạy để tạo các bảng (Tables) cần thiết.
- **Keycloak (Import Realm):** Do sử dụng Helm Chart tiêu chuẩn (không có Keycloak Operator), bạn cần Import Realm một lần duy nhất:
  1. Đăng nhập vào trang quản trị Keycloak (`admin / admin`).
  2. Mở file có sẵn tại: `yas/k8s/deploy/keycloak/keycloak/templates/keycloak-yas-realm-import.yaml` trong repo mã nguồn gốc.
  3. Lấy dữ liệu ở phần `spec.realm:` (chuyển đổi YAML sang JSON nếu cần) và dùng tính năng **Create Realm** trên giao diện Keycloak để Import file JSON này vào. Quá trình này sẽ khôi phục lại toàn bộ Client IDs, Users, và cấu hình Realm `Yas`.
- **Mạng Lưới (Istio & Tailscale):** Vì `storefront-nextjs` (trên cụm nqthang) cần gửi request tới `storefront-bff` (trên cụm tdquan), hãy đảm bảo rằng DNS/ServiceEntry giữa 2 cụm đã được khai báo chính xác qua Istio Multi-cluster, hoặc ứng dụng Frontend được cấu hình biến môi trường gọi thẳng tới IP/Domain Name của Ingress Gateway thuộc cụm `tdquan`.

## 5. Cấu trúc File Chính
- `helm/yas/Chart.yaml`: Khai báo các Dependencies (Keycloak, Postgres, Redis, Kafka, Elasticsearch).
- `helm/yas/values.yaml`: Cấu hình toàn cục, cấu hình port 3000 cho Next.js, định nghĩa image tags.
- `helm/yas/values-tdquan.yaml`: Bật (`enabled: true`) tất cả các backend services và nền tảng hạ tầng.
- `helm/yas/values-nqthang.yaml`: Chỉ bật các frontend services.
- `helm/yas/templates/gateway-routes-configmap.yaml`: Nơi cấu hình đường dẫn API Gateway cho BFF thay thế cho việc sử dụng NGINX proxy. Mọi thay đổi về API Paths cần được chỉnh sửa ở đây.

---

## 6. Istio Service Mesh Demo (namespace `test`)

Helm chart demo các tính năng cốt lõi của **Istio Service Mesh** trong namespace `test`, bao gồm: Sidecar Injection, mTLS, Authorization Policy, VirtualService Retry và quan sát qua **Kiali**.

### 6.1. Chi tiết các File Cấu Hình (Cấu trúc thư mục)

```
helm/istio-demo/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── namespace.yaml            ← label: istio-injection=enabled
    ├── service-accounts.yaml     ← SPIFFE identity cho từng service
    ├── deployments.yaml          ← httpbin × 2, sleep-client × 1
    ├── services.yaml             ← ClusterIP cho product-svc, order-svc
    └── istio/
        ├── peer-authentication.yaml   ← mTLS STRICT toàn namespace
        ├── authorization-policy.yaml  ← 1 deny-all + 2 allow policies
        ├── virtual-service.yaml       ← retry 3x / 2s cho product-svc
        └── destination-rule.yaml      ← connection pool + outlier detection
```

### 6.2. Kiến trúc & Phân quyền

```text
┌─────────────────────────────── namespace: test ─────────────────────────────────┐
│                                                                                   │
│   ┌─────────────────┐   🔒 mTLS ALLOW   ┌───────────────────────────────────┐   │
│   │                 │ ────────────────▶ │          product-svc              │   │
│   │   sleep-client  │                   │   (httpbin · port 80)             │   │
│   │  (curl client)  │                   │   VirtualService: retry 3x on 5xx │   │
│   │                 │   ⛔ DENY (403)   └──────────────┬────────────────────┘   │
│   │                 │ ──────────────────────────┐      │                        │
│   └─────────────────┘                           │      │ 🔒 mTLS ALLOW          │
│                                                 ▼      ▼                        │
│                                      ┌─────────────────────────┐                │
│                                      │        order-svc        │                │
│                                      │   (httpbin · port 80)   │                │
│                                      │   Không có retry        │                │
│                                      └─────────────────────────┘                │
│                                                                                   │
│  🔐 PeerAuthentication: STRICT mTLS — mọi traffic đều được mã hóa + xác thực      │
└───────────────────────────────────────────────────────────────────────────────────┘
```

**Luồng traffic và policy:**
| Caller | Callee | Policy | Kết quả |
|---|---|---|---|
| `sleep-client` | `product-svc` | `allow-sleep-to-product` | ✅ HTTP 200 |
| `sleep-client` | `order-svc` | Không có (default-deny) | ⛔ HTTP 403 |
| `product-svc` | `order-svc` | `allow-product-to-order` | ✅ HTTP 200 |
| `sleep-client` | `product-svc/status/500` | allow + **retry 3 lần** | 🔄 Retry → 500 |

### 6.3. Triển khai (Deploy)

**Yêu cầu:** 
- Kubernetes cluster đang chạy (minikube, kind, k3s, hoặc cloud).
- Istio đã được cài (`istiod`, `istio-ingressgateway` đang Running).

**Cách 1 — Dùng Helm CLI (Local)**
```bash
# 1. Tạo namespace và gán label Helm + Istio
kubectl create namespace test --dry-run=client -o yaml | kubectl apply -f -

kubectl label namespace test \
  istio-injection=enabled \
  app.kubernetes.io/managed-by=Helm \
  --overwrite

kubectl annotate namespace test \
  meta.helm.sh/release-name=istio-demo \
  meta.helm.sh/release-namespace=test \
  --overwrite

# 2. Cài đặt Chart
helm install istio-demo ./helm/istio-demo -n test

# 3. Chờ tất cả pod khởi chạy (READY 2/2)
kubectl get pods -n test -w
```
*(Nếu bỏ qua bước 1, `helm install` có thể báo lỗi `invalid ownership metadata`)*

**Cách 2 — Dùng ArgoCD**
```bash
kubectl apply -f argocd/applications/istio-demo.yaml
```

**Gỡ cài đặt**
```bash
helm uninstall istio-demo -n test
kubectl delete namespace test
```

### 6.4. Hướng dẫn Test & Khắc phục Lỗi (Troubleshoot)

> ⚠️ **Quan trọng về Circuit Breaker**: 
> Trong file `DestinationRule`, chúng ta cấu hình `outlierDetection.maxEjectionPercent: 100`. Nếu một service liên tục trả về lỗi 5xx, Envoy sẽ eject (đá) instance đó ra khỏi pool. Nếu test `/status/500` quá nhiều lần, bạn sẽ bị chặn hoàn toàn và nhận lỗi `503 Service Unavailable` thay vì `500`.

**Xử lý khi gặp lỗi 503 (Restart Envoy Ejection State):**
```bash
# Restart deployment để Envoy làm mới trạng thái connection/ejection
kubectl rollout restart deployment/product-svc -n test
kubectl rollout status deployment/product-svc -n test
```

**Thực hiện Test Thủ Công:**

**Bước 0: Lấy tên pod sleep-client làm một biến môi trường**
```bash
SLEEP=$(kubectl get pod -n test -l app=sleep-client -o jsonpath='{.items[0].metadata.name}')
```

**Bước 1: Kiểm tra mTLS & Sidecar Injection**
```bash
# Trạng thái READY phải là 2/2 (nghĩa là có container application và container istio-proxy)
kubectl get pods -n test 
# Phân tích toàn bộ config Istio xem có báo lỗi không
istioctl analyze -n test 
```

**Bước 2: Test AuthorizationPolicy (Áp dụng ALLOW)**
```bash
# Gọi từ sleep sang product (rule đã cấp quyền)
kubectl exec -n test $SLEEP -- curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://product-svc/status/200
# Kết quả mong đợi: HTTP Status: 200
```

**Bước 3: Test AuthorizationPolicy (Áp dụng DENY)**
```bash
# Gọi từ sleep sang order (bị chặn bởi Default Deny All, không có quyền)
kubectl exec -n test $SLEEP -- curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://order-svc/status/200
# Kết quả mong đợi: HTTP Status: 403
```

**Bước 4: Test VirtualService (Retry & Response Flag "URX")**
Theo cấu hình `VirtualService`, Envoy Proxy tại client sẽ tự động thử lại 3 lần khi điểm đến trả về lỗi 5xx.

```bash
# 1. Bắn request bị lỗi (server sẽ luôn trả lời lỗi HTTP 500)
kubectl exec -n test $SLEEP -- curl -s http://product-svc/status/500

# 2. Xem log tại phía SERVER (product-svc) để quan sát số lần thử (attempts)
PRODUCT=$(kubectl get pod -n test -l app=product-svc -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n test $PRODUCT -c istio-proxy | grep "GET /status/500"
# -> Bạn sẽ thấy 3 dòng log lưu vết của 1 request duy nhất nhưng được gọi 3 lần, thông qua: x-envoy-attempt-count: 1/2/3

# 3. Xem log tại phía CLIENT (sleep-client) để xem kết quả cuối cùng phản hồi về có flag "URX" không
kubectl logs -n test $SLEEP -c istio-proxy | grep "GET /status/500"
# -> Ghi chú: Bạn sẽ thấy cờ \`response_flags="URX"\` ở gần cuối dòng log. 
# "URX" (Upstream Retry Limit Exceeded) xác nhận rằng Istio đã cố thử lại nhưng hết số lần cho phép (Attempts Limit = 3).
```
*(Hoặc chạy lệnh kiểm thử tự động toàn bộ: `bash docs/istio-demo-test.sh`)*

### 6.5. Quan sát trên Kiali
Dùng lệnh:
```bash
istioctl dashboard kiali
```
Vào `Graph`, chọn `Namespace: test`. Bạn sẽ dễ dàng quan sát thấy Topology (đường xanh lá là mTLS hoạt động và ALLOW, đường đỏ là DENY (403)), cũng như thấy được sự gia tăng Retry thông qua metrics của từng Node.