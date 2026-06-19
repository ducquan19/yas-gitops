# Service Distribution

Tai lieu nay mo ta cach chia service YAS theo cluster va theo environment. ArgoCD hien quan ly theo ma tran:

```text
cluster x environment
```

Trong do environment gom:

- `dev` -> branch `main`, namespace `yas-dev`
- `staging` -> branch `staging`, namespace `yas-staging`

## Mapping cluster

| Cluster | Dev app | Staging app | Cluster values | Service |
| --- | --- | --- | --- | --- |
| cluster-1 | `tdquan-dev` | `tdquan-staging` | `helm/yas/values-tdquan.yaml` | `postgres`, `elasticsearch`, `promotion`, `location`, `webhook` |
| cluster-2 | `tbnguyen274-dev` | `tbnguyen274-staging` | `helm/yas/values-tbnguyen274.yaml` | `product`, `inventory`, `search`, `media`, `recommendation` |
| cluster-3 | `avocado2-dev` | `avocado2-staging` | `helm/yas/values-avocado2.yaml` | `cart`, `order`, `payment`, `delivery`, `tax` |
| cluster-4 | `nqthang-dev` | `nqthang-staging` | `helm/yas/values-nqthang.yaml` | `storefront`, `storefront-bff`, `backoffice`, `backoffice-bff`, `customer`, `identity`, `kafka`, `rating` |

## Environment values

Environment override nam trong:

| Environment | Values file |
| --- | --- |
| `dev` | `helm/yas/values-dev.yaml` |
| `staging` | `helm/yas/values-staging.yaml` |

Moi Application ghep values theo thu tu:

```text
values.yaml
values-<cluster>.yaml
values-<environment>.yaml
```

Nho do, cluster values quyet dinh service subset va image tag can promote. Environment values chi nen dung cho config rieng cua `dev` hoac `staging`.

## Nguyen tac deploy

- Moi service co `image.tag` mac dinh la `main`.
- Jenkins update cluster values tren branch `main`.
- Dev auto deploy vi cac app `*-dev` theo doi branch `main`.
- Staging khong bi anh huong khi `main` thay doi.
- Staging chi deploy khi merge/push tag config sang branch `staging`.

Vi du:

```text
TAX_SERVICE_BRANCH=release_tax_service
```

Ket qua:

- Jenkins update `tax.image.tag` trong `helm/yas/values-avocado2.yaml` tren branch `main`.
- ArgoCD app `avocado2-dev` sync cluster-3 vao namespace `yas-dev`.
- Khi release ready, merge `main` sang `staging`.
- ArgoCD app `avocado2-staging` sync cluster-3 vao namespace `yas-staging`.
