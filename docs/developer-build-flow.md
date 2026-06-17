# Developer Build Flow

Job `developer_build` dùng cho developer deploy nhanh branch đang làm việc để test trên Kubernetes. Theo đề bài, developer nhập branch của service cần test, các service còn lại giữ `main` hoặc `latest`.

## Yêu cầu từ đề bài

- Job tên `developer_build`.
- Developer input parameter là branch muốn deploy cho từng service.
- CI đã build image từ branch và push lên Docker Hub với tag là commit id cuối của branch.
- CD dùng tag từ branch đó để deploy service cần test.
- Sau deploy, developer nhận được domain/IP + NodePort để truy cập.

## Luồng GitOps

```text
1. Developer mở Jenkins job developer_build.
2. Nhập branch cho service cần test, ví dụ TAX_SERVICE_BRANCH=dev_tax_service.
3. Jenkins resolve branch dev_tax_service -> commit id/tag image đã build bởi CI.
4. Jenkins tìm service tax thuộc cluster avocado2.
5. Jenkins update helm/yas/values-avocado2.yaml:
   tax.image.tag=<commit-id>
6. Jenkins commit và push thay đổi vào GitOps repo.
7. ArgoCD app avocado2 tự động sync và deploy cluster-3.
8. Jenkins in URL NodePort để developer test.
```

## Vi du tax-service

Input:

| Parameter | Giá trị |
| --- | --- |
| `TAX_SERVICE_BRANCH` | `dev_tax_service` |
| Các service khác | `main` |

Kết quả:

```yaml
tax:
  enabled: true
  image:
    tag: <commit-id-của-branch-dev_tax_service>
```

Trong bản đơn giản nếu chưa resolve được commit id, có thể tạm dùng branch name làm tag image, nhưng cần đảm bảo CI cũng push image với tag đó.

## Trạng thái Jenkinsfile hiện tại

`jenkins/Jenkinsfile.developer_build` hiện nhận branch/tag parameter nhưng deploy trực tiếp bằng Helm:

```text
helm upgrade --install ...
```

Để đúng yêu cầu "ArgoCD deploy từng phần lên nhiều cluster", cần chỉnh job theo hướng:

- Không `helm upgrade` trực tiếp.
- Dùng script resolve branch -> image tag.
- Update values file theo mapping service -> cluster.
- Commit và push lên GitOps repo.
- Để ArgoCD automated sync deploy.

## Parameters nên có

| Parameter | Default | Mô tả |
| --- | --- | --- |
| `NAMESPACE` | `yas` | Namespace deploy. |
| `TAX_SERVICE_BRANCH` | `main` | Branch/tag của tax service. |
| `ORDER_SERVICE_BRANCH` | `main` | Branch/tag của order service. |
| `PRODUCT_SERVICE_BRANCH` | `main` | Branch/tag của product service. |
| `SEARCH_SERVICE_BRANCH` | `main` | Branch/tag của search service. |
| `CUSTOMER_SERVICE_BRANCH` | `main` | Branch/tag của customer service. |
| `FRONTEND_BRANCH` | `main` | Branch/tag của frontend/storefront. |

Có thể thêm parameter cho các service còn lại nếu cần test độc lập.
