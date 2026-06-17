# Service Distribution

Tài liệu này mô tả cách chia service YAS lên 4 Kubernetes cluster. Đây là cơ sở để Jenkins tự xác định service nào thuộc cluster nào khi developer nhập branch trong job `developer_build`.

## Mapping cluster

| Cluster | ArgoCD app | Values file | Service |
| --- | --- | --- | --- |
| cluster-1 | `tdquan` | `helm/yas/values-tdquan.yaml` | `postgres`, `elasticsearch`, `promotion`, `location`, `webhook` |
| cluster-2 | `tbnguyen274` | `helm/yas/values-tbnguyen274.yaml` | `product`, `inventory`, `search`, `media`, `recommendation` |
| cluster-3 | `avocado2` | `helm/yas/values-avocado2.yaml` | `cart`, `order`, `payment`, `delivery`, `tax` |
| cluster-4 | `nqthang` | `helm/yas/values-nqthang.yaml` | `storefront`, `storefront-bff`, `backoffice`, `backoffice-bff`, `customer`, `identity`, `kafka`, `rating` |

## Nguyên tắc deploy

- Mỗi service có `image.tag` mặc định là `main`.
- Khi developer muốn test một branch riêng, chỉ tag của service đó được cập nhật.
- Jenkins cần tra mapping service -> values file để chỉ update đúng cluster.
- ArgoCD sẽ sync Application của cluster có values file thay đổi.

Ví dụ:

```text
TAX_SERVICE_BRANCH=dev_tax_service
Cac service khac=main
```

Kết quả mong muốn:

- Jenkins chỉ update `tax.image.tag` trong `helm/yas/values-avocado2.yaml`.
- ArgoCD app `avocado2` sync lại cluster-3.
- Các cluster/service còn lại tiếp tục dùng tag `main`.

## Lưu ý đặt tên service

Tên parameter trên Jenkins nên rõ ràng và khớp với service trong values:

| Jenkins parameter | Service trong values | Cluster |
| --- | --- | --- |
| `TAX_SERVICE_BRANCH` | `tax` | cluster-3 |
| `ORDER_SERVICE_BRANCH` | `order` | cluster-3 |
| `PRODUCT_SERVICE_BRANCH` | `product` | cluster-2 |
| `SEARCH_SERVICE_BRANCH` | `search` | cluster-2 |
| `CUSTOMER_SERVICE_BRANCH` | `customer` | cluster-4 |
| `FRONTEND_BRANCH` | `storefront` hoặc frontend service tương ứng | cluster-4 |

Nếu code CI build image theo tên khác, cần đồng bộ lại tên repository image trong Helm chart.
