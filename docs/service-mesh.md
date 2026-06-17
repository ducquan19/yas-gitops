# Service Mesh

Phần nâng cao yêu cầu cấu hình service mesh cho YAS trên Kubernetes, gồm mTLS, topology/Kiali, retry policy và authorization policy.

## Mục tiêu

- Bật mTLS giữa các service.
- Giới hạn service-to-service access bằng AuthorizationPolicy.
- Cấu hình retry khi service trả lời 500.
- Có topology Kiali và test log làm bằng chứng.


## Checklist cài đặt

```bash
istioctl install --set profile=demo -y
kubectl label namespace yas istio-injection=enabled
kubectl rollout restart deployment -n yas
```

Kiểm tra sidecar:

```bash
kubectl -n yas get pods
kubectl -n yas describe pod <pod-name>
```

Mỗi pod nên có container app và `istio-proxy`.

## mTLS

Manifest nên đặt trong `helm/yas/templates/istio/peer-authentication.yaml`:

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: yas-strict-mtls
  namespace: yas
spec:
  mtls:
    mode: STRICT
```

Bằng chứng:

```bash
istioctl authn tls-check <pod-name>.<namespace>
```

## Authorization policy

Mục tiêu: chỉ service được phép mới gọi được nhau. Ví dụ chỉ `cart` và `order` được gọi `tax`:

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: tax-allow-cart-order
  namespace: yas
spec:
  selector:
    matchLabels:
      app: tax
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/yas/sa/cart
              - cluster.local/ns/yas/sa/order
```

Test:

```bash
kubectl -n yas exec deploy/cart -- curl -v http://tax:8080/
kubectl -n yas exec deploy/product -- curl -v http://tax:8080/
```

Kết quả mong muốn:

- `cart -> tax`: allowed.
- `product -> tax`: denied hoặc 403.

## Retry policy

Retry nên đặt trong `helm/yas/templates/istio/virtual-service.yaml`. Ví dụ:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: tax-retry
  namespace: yas
spec:
  hosts:
    - tax
  http:
    - route:
        - destination:
            host: tax
            port:
              number: 8080
      retries:
        attempts: 3
        perTryTimeout: 2s
        retryOn: 5xx,gateway-error,connect-failure,refused-stream
```

Bằng chứng:

- Log service bị gọi cho thấy nhiều request khi service trả 500.
- `istio-proxy` access log có request retry.
- Kiali hiện traffic edge giữa các service.

## Kiali topology

Lệnh mở Kiali:

```bash
istioctl dashboard kiali
```

Cần chụp:

- Topology namespace `yas`.
- Flow giữa frontend/BFF/backend service.
- Cảnh báo policy nếu có.
