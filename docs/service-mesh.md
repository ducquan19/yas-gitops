# Service Mesh

Phan nang cao cau hinh service mesh cho YAS tren Kubernetes, gom mTLS, AuthorizationPolicy, retry policy va Kiali topology.

## Namespaces

Project hien co hai namespace ung dung:

```text
yas-dev
yas-staging
```

Chon namespace theo environment can test.

## Checklist

Vi du cho dev:

```bash
istioctl install --set profile=demo -y
kubectl label namespace yas-dev istio-injection=enabled --overwrite
kubectl rollout restart deployment -n yas-dev
```

Vi du cho staging:

```bash
kubectl label namespace yas-staging istio-injection=enabled --overwrite
kubectl rollout restart deployment -n yas-staging
```

Kiem tra sidecar:

```bash
kubectl -n yas-dev get pods
kubectl -n yas-dev describe pod <pod-name>
```

Moi pod nen co container app va `istio-proxy`.

## mTLS

Manifest nen render theo namespace deploy hien tai:

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: yas-strict-mtls
spec:
  mtls:
    mode: STRICT
```

Bang chung:

```bash
istioctl authn tls-check <pod-name>.<namespace>
```

## Authorization Policy

Vi du chi cho `cart` va `order` goi `tax` trong namespace `yas-dev`:

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: tax-allow-cart-order
  namespace: yas-dev
spec:
  selector:
    matchLabels:
      app: tax
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/yas-dev/sa/cart
              - cluster.local/ns/yas-dev/sa/order
```

Test:

```bash
kubectl -n yas-dev exec deploy/cart -- curl -v http://tax:8080/
kubectl -n yas-dev exec deploy/product -- curl -v http://tax:8080/
```

Ket qua mong muon:

- `cart -> tax`: allowed.
- `product -> tax`: denied hoac 403.

## Retry Policy

Retry nen dat trong `helm/yas/templates/istio/virtual-service.yaml`.

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: tax-retry
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

## Kiali Topology

```bash
istioctl dashboard kiali
```

Can chup bang chung:

- Topology namespace `yas-dev` hoac `yas-staging`.
- Flow giua frontend/BFF/backend service.
- Canh bao policy neu co.
