# Naming Conventions

Tai lieu nay thong nhat cach dat ten trong repo GitOps, Jenkins, Helm va ArgoCD.

## General

- Service, file, release, namespace va ArgoCD application dung lowercase kebab-case.
- Jenkins parameter dung UPPER_SNAKE_CASE.
- Khong dung khoang trang trong branch, tag, service, namespace hoac file.
- Service key trong Helm values phai khop voi key chart dang dung.
- Image tag phai khop voi tag da duoc CI build va push len registry.

## Branch

Branch nen the hien muc dich thay doi va service lien quan:

```text
dev_<service_name>
feature/<service-name>-<short-description>
fix/<service-name>-<short-description>
rc_v<major>.<minor>.<patch>
```

Vi du:

```text
dev_tax_service
feature/tax-service-add-vat-rule
fix/order-service-payment-status
rc_v1.2.3
```

## Jenkins Parameter

Service branch parameter:

```text
<SERVICE>_BRANCH
```

Vi du:

```text
TAX_SERVICE_BRANCH
ORDER_SERVICE_BRANCH
PRODUCT_SERVICE_BRANCH
SEARCH_SERVICE_BRANCH
CUSTOMER_SERVICE_BRANCH
STOREFRONT_BRANCH
```

Parameter chung:

```text
CLEANUP_MODE
SOURCE_REPO_URL
```

GitOps environment branches:

```text
main
staging
```

## Helm Values

Cluster values dung format:

```text
values-<cluster-owner>.yaml
```

Vi du:

```text
values-tdquan.yaml
values-tbnguyen274.yaml
values-avocado2.yaml
values-nqthang.yaml
```

Environment values dung format:

```text
values-<environment>.yaml
```

Vi du:

```text
values-dev.yaml
values-staging.yaml
```

Service key trong values dung lowercase, uu tien khop voi chart:

```yaml
tax:
  image:
    tag: main
```

Mot so mapping service:

| Jenkins/report name | Values key |
| --- | --- |
| `tax-service` | `tax` |
| `order-service` | `order` |
| `product-service` | `product` |
| `search-service` | `search` |
| `customer-service` | `customer` |
| `frontend` | `storefront` |

## ArgoCD

Application name dung format:

```text
<cluster-owner>-<environment>
```

Vi du:

```text
tdquan-dev
tdquan-staging
tbnguyen274-dev
tbnguyen274-staging
avocado2-dev
avocado2-staging
nqthang-dev
nqthang-staging
```

AppProject:

```text
yas
```

Namespace ArgoCD:

```text
argocd
```

Namespace deploy:

```text
yas-dev
yas-staging
```

## Helm Release

Helm release nen co format:

```text
yas-<cluster-name>-<environment>
```

Vi du:

```text
yas-cluster-1-dev
yas-cluster-1-staging
```

## Kubernetes Resource

Kubernetes resource nen dung kebab-case:

```text
yas-tax
yas-order
yas-storefront
tax-service
order-service
```

Label toi thieu nen co:

```yaml
app.kubernetes.io/name: tax
app.kubernetes.io/part-of: yas
app.kubernetes.io/managed-by: argocd
```
