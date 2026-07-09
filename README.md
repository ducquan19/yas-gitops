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

## 6. Istio Service Mesh Demo

Hướng dẫn từng bước demo các tính năng cốt lõi của Istio: Sidecar Injection, mTLS, AuthorizationPolicy, VirtualService Retry và quan sát qua Kiali.

**Yêu cầu:**
- Istio đã cài (`istiod` đang Running trong namespace `istio-system`)
- Observability stack đã deploy (namespace `observability`)

---

### Bước 1 — Kích hoạt Sidecar Injection cho namespace

```bash
# Gán label để Istio tự inject sidecar vào mọi pod mới trong namespace
kubectl label namespace yas-dev istio-injection=enabled --overwrite

# Restart toàn bộ pods hiện tại để inject sidecar
kubectl rollout restart deployment -n yas-dev

# Kiểm tra: tất cả pods phải READY 2/2 (app + istio-proxy)
kubectl get pods -n yas-dev -w
```

---

### Bước 2 — Deploy nhóm services demo

Dùng Helm chart `istio-demo` để deploy các mock services (httpbin) phục vụ demo:

```bash
# Tạo namespace với đúng label và annotation
kubectl create namespace yas-dev --dry-run=client -o yaml | kubectl apply -f -

kubectl label namespace yas-dev istio-injection=enabled \
  app.kubernetes.io/managed-by=Helm --overwrite

kubectl annotate namespace yas-dev \
  meta.helm.sh/release-name=istio-demo \
  meta.helm.sh/release-namespace=yas-dev --overwrite

# Cài chart
helm install istio-demo ./helm/istio-demo -n yas-dev

# Chờ pods READY 2/2
kubectl get pods -n yas-dev -w
```

Hoặc dùng ArgoCD:
```bash
kubectl apply -f argocd/applications/istio-demo.yaml
```

---

### Bước 3 — Bật mTLS bằng PeerAuthentication

Apply policy mTLS STRICT cho toàn namespace — mọi traffic nội bộ đều được mã hóa và xác thực:

```yaml
# helm/istio-demo/templates/istio/peer-authentication.yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: yas-dev
spec:
  mtls:
    mode: STRICT
```

```bash
kubectl apply -f helm/istio-demo/templates/istio/peer-authentication.yaml

# Xác nhận
kubectl get peerauthentication -n yas-dev
```

---

### Bước 4 — Tạo AuthorizationPolicy

Mô hình: **default deny-all**, rồi mở từng cặp service được phép gọi nhau:

```yaml
# helm/istio-demo/templates/istio/authorization-policy.yaml

# 1. Chặn tất cả (default deny-all)
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: yas-dev
spec: {}
---
# 2. Cho phép sleep-client gọi product
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-to-product
  namespace: yas-dev
spec:
  selector:
    matchLabels:
      app: product
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/yas-dev/sa/sleep-client"]
---
# 3. Cho phép storefront-bff gọi order
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-to-order
  namespace: yas-dev
spec:
  selector:
    matchLabels:
      app: order
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/yas-dev/sa/storefront-bff"]
```

| Caller | Callee | Kết quả |
|---|---|---|
| `sleep-client` | `product` | ✅ HTTP 200 |
| `sleep-client` | `cart` | ⛔ HTTP 403 (default-deny) |
| `storefront-bff` | `order` | ✅ HTTP 200 |

---

### Bước 5 — Tạo VirtualService Retry

Cấu hình Envoy tự động retry 3 lần khi service trả về lỗi 5xx:

```yaml
# helm/istio-demo/templates/istio/virtual-service.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: product-vs
  namespace: yas-dev
spec:
  hosts:
  - product
  http:
  - retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: 5xx
    route:
    - destination:
        host: product
```

---

### Bước 6 — Test Retry khi service trả lỗi 500

```bash
# Lấy tên pod sleep-client
SLEEP=$(kubectl get pod -n yas-dev -l app=sleep-client -o jsonpath='{.items[0].metadata.name}')

# Gửi request tới endpoint luôn trả lỗi 500
kubectl exec -n yas-dev $SLEEP -- curl -s http://product/status/500
```

Xem log để xác nhận retry:
```bash
# Phía SERVER: sẽ thấy 3 lần nhận request (x-envoy-attempt-count: 1, 2, 3)
PRODUCT=$(kubectl get pod -n yas-dev -l app=product -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n yas-dev $PRODUCT -c istio-proxy | grep "GET /status/500"

# Phía CLIENT: sẽ thấy response_flags="URX" (Upstream Retry Limit Exceeded)
kubectl logs -n yas-dev $SLEEP -c istio-proxy | grep "GET /status/500"
```

> ⚠️ Nếu test nhiều lần liên tục và nhận `503` thay vì `500`, đó là Circuit Breaker đang hoạt động. Reset bằng:
> ```bash
> kubectl rollout restart deployment/product -n yas-dev
> ```

---

### Bước 7 — Mở Kiali & Xem Topology

```bash
# Kiali nằm trong namespace observability
kubectl port-forward svc/kiali -n observability 20001:20001 --address 0.0.0.0
```

Truy cập: **http://localhost:20001**

**Cách xem trên Kiali:**
1. Vào menu **Graph**
2. Chọn **Namespace: `yas-dev`**
3. Quan sát topology:
   - 🟢 **Đường xanh lá + khóa** = mTLS ALLOW
   - 🔴 **Đường đỏ** = DENY 403 từ AuthorizationPolicy
   - **Badge 🔄** trên node = có retry đang xảy ra

> **Lưu ý:** Nếu Kiali báo lỗi `unable to proxy Istiod` hoặc `no such host`, chạy lệnh fix sau (1 lần duy nhất):
> ```bash
> kubectl get configmap kiali -n observability -o yaml > /tmp/kiali-cm.yaml
> sed -i 's/istio_namespace: observability/istio_namespace: istio-system/g' /tmp/kiali-cm.yaml
> sed -i 's/root_namespace: observability/root_namespace: istio-system/g' /tmp/kiali-cm.yaml
> kubectl apply -f /tmp/kiali-cm.yaml
> kubectl rollout restart deployment/kiali -n observability
> ```