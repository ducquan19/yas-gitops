# Quy ước đặt tên

Tài liệu này thống nhất cách đặt tên trong repo GitOps, Jenkins, Helm, ArgoCD và báo cáo. Mục tiêu là tránh lệch tên giữa service, image, values file và Jenkins parameter.

## Nguyên tắc chung

- Dùng chữ thường và dấu gạch ngang `-` cho tên service, file, release, namespace và ArgoCD application.
- Dùng chữ hoa và dấu gạch dưới `_` cho Jenkins parameter.
- Không dùng khoảng trắng trong tên branch, tag, service, namespace hoặc file.
- Tên service trong Helm values phải khớp với tên service được dùng trong chart.
- Tên image tag phải khớp với tag đã được CI build và push lên Docker Hub.

## Branch

Branch nên thể hiện mục đích thay đổi và service liên quan:

```text
dev_<service_name>
feature/<service-name>-<short-description>
fix/<service-name>-<short-description>
rc_v<major>.<minor>.<patch>
```

Ví dụ:

```text
dev_tax_service
feature/tax-service-add-vat-rule
fix/order-service-payment-status
rc_v1.2.3
```

Với job `developer_build`, branch developer nhập sẽ được resolve sang image tag. Nếu CI dùng commit id làm tag, Jenkins cần lấy commit id cuối của branch đó.

## Docker image tag

Theo đề bài, CI nên build image với tag là commit id cuối cùng của branch:

```text
<short-commit-id>
```

Ví dụ:

```text
a1b2c3d
```

Các tag mặc định:

```text
main
latest
```

Khuyến nghị dùng `main` làm default trong GitOps values để dễ truy vết.

## Service

Tên service dùng dạng `kebab-case`:

```text
tax-service
order-service
product-service
search-service
customer-service
storefront
storefront-bff
```

Trong Helm values hiện tại, một số service được rút gọn:

| Tên trong báo cáo/Jenkins | Tên trong values |
| --- | --- |
| `tax-service` | `tax` |
| `order-service` | `order` |
| `product-service` | `product` |
| `search-service` | `search` |
| `customer-service` | `customer` |
| `frontend` | `storefront` |

Khi viết Jenkins mapping, cần map rõ từ tên Jenkins sang key trong values.

## Jenkins parameter

Jenkins parameter dùng `UPPER_SNAKE_CASE`:

```text
<SERVICE>_BRANCH
```

Ví dụ:

```text
TAX_SERVICE_BRANCH
ORDER_SERVICE_BRANCH
PRODUCT_SERVICE_BRANCH
SEARCH_SERVICE_BRANCH
CUSTOMER_SERVICE_BRANCH
FRONTEND_BRANCH
```

Các parameter chung:

```text
NAMESPACE
TARGET_CLUSTER
CLEANUP_MODE
```

Default của branch parameter nên là:

```text
main
```

## Helm values

File values theo cluster dùng format:

```text
values-<cluster-owner>.yaml
```

Ví dụ:

```text
values-tdquan.yaml
values-tbnguyen274.yaml
values-avocado2.yaml
values-nqthang.yaml
```

Key service trong values dùng chữ thường:

```yaml
tax:
  enabled: true
  image:
    tag: main
```

Nếu service có nhiều từ, ưu tiên giữ đúng tên chart đang dùng. Ví dụ:

```yaml
storefront-bff:
  enabled: true
  image:
    tag: main
```

## ArgoCD

ArgoCD Application dùng tên ngắn, chữ thường, khớp với cluster:

```text
tdquan
tbnguyen274
avocado2
nqthang
```

AppProject:

```text
yas
```

Namespace ArgoCD:

```text
argocd
```

Namespace deploy ứng dụng:

```text
yas
```

## Helm release

Tên Helm release nên có format:

```text
yas-<cluster-name>
```

Ví dụ:

```text
yas-cluster-1
yas-cluster-2
yas-cluster-3
yas-cluster-4
```


## Kubernetes resource

Kubernetes resource nên dùng `kebab-case`:

```text
yas-tax
yas-order
yas-storefront
tax-service
order-service
```

Label tối thiểu nên có:

```yaml
app.kubernetes.io/name: tax
app.kubernetes.io/part-of: yas
app.kubernetes.io/managed-by: argocd
```

## Kubernetes Deployment

Deployment nên đặt tên theo service đang deploy. Khuyến nghị trong project này là dùng đúng service key trong values.

Ví dụ:

```text
tax
order
product
search
customer
storefront
storefront-bff
```

Nếu muốn tránh trùng tên khi gom nhiều chart, có thể thêm prefix:

```text
yas-tax
yas-order
yas-storefront
```

### Labels và selector

Labels phải thống nhất giữa `Deployment`, `Pod template` và `Service selector`.

Ví dụ với `tax`:

```yaml
metadata:
  labels:
    app.kubernetes.io/name: tax
    app.kubernetes.io/part-of: yas
    app.kubernetes.io/managed-by: argocd
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: tax
  template:
    metadata:
      labels:
        app.kubernetes.io/name: tax
        app.kubernetes.io/part-of: yas
```

Không nên để selector dùng một tên còn pod label dùng tên khác, vì Service sẽ không route traffic đến pod.

### Container name

Container name nên trùng với service key:

```yaml
containers:
  - name: tax
```

### Image

Image nên lấy từ values:

```yaml
image: "{{ .Values.tax.image.repository }}:{{ .Values.tax.image.tag }}"
```

Nếu values hiện chỉ có `image.tag`, cần bổ sung thêm `image.repository` để chart render đủ image:

```yaml
tax:
  enabled: true
  image:
    repository: <dockerhub-user>/yas-tax
    tag: main
```

### Replicas

Replicas nên đặt trong values:

```yaml
tax:
  replicaCount: 1
```

Trong môi trường dev/test, `replicaCount: 1` là đủ. Với staging có thể tăng lên `2`.

### Port

Container port nên đặt rõ trong values hoặc dùng default theo service:

```yaml
tax:
  service:
    port: 8080
    type: NodePort
```

Deployment:

```yaml
ports:
  - name: http
    containerPort: 8080
```

Service:

```yaml
ports:
  - name: http
    port: 8080
    targetPort: http
```

### Env và ConfigMap/Secret

Biến môi trường không nên hard-code trong Deployment. Nên tách:

- Config không nhạy cảm: `ConfigMap`
- Thông tin nhạy cảm: `Secret`

Ví dụ:

```yaml
envFrom:
  - configMapRef:
      name: tax-config
  - secretRef:
      name: tax-secret
```

### Health check

Mỗi Deployment nên có `readinessProbe` và `livenessProbe` nếu service có endpoint health:

```yaml
readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: http
livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: http
```

Nếu service chưa bật Spring Boot actuator readiness/liveness, có thể dùng `/actuator/health`.

### Resources

Nên đặt request/limit để tránh pod dùng quá nhiều tài nguyên:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### ServiceAccount

Nếu dùng Istio AuthorizationPolicy theo principal, mỗi service nên có ServiceAccount riêng:

```text
tax
order
cart
```

Ví dụ principal:

```text
cluster.local/ns/yas/sa/tax
```
