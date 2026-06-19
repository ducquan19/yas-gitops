# Developer Build Flow

Job `developer_build` dung de developer deploy nhanh branch dang lam viec vao moi truong `dev`.

## Yeu cau

- Developer nhap branch/tag cho service can test.
- CI da build image tu branch va push image tag tuong ung.
- Jenkins chi cap nhat values file tren branch `main` cua GitOps repo.
- ArgoCD dev tu dong sync Application theo branch `main`.
- Staging chi deploy khi merge/push config sang branch `staging`.

## Luong GitOps

```text
1. Developer mo Jenkins job developer_build.
2. Nhap branch cho service can test, vi du TAX_SERVICE_BRANCH=dev_tax_service.
3. Jenkins resolve branch -> image tag.
4. Jenkins update values file theo cluster, vi du helm/yas/values-avocado2.yaml.
5. Jenkins commit va push thay doi vao branch `main`.
6. ArgoCD dev sync Application tuong ung, vi du avocado2-dev.
7. Khi release ready, merge `main` sang `staging`.
8. ArgoCD staging sync Application tuong ung, vi du avocado2-staging.
9. Jenkins in access hint de developer test qua NodePort.
```

## Vi du tax-service vao dev

Input:

| Parameter | Gia tri |
| --- | --- |
| `TAX_SERVICE_BRANCH` | `dev_tax_service` |
| Cac service khac | `main` |

Ket qua trong `helm/yas/values-avocado2.yaml` tren branch `main`:

```yaml
tax:
  image:
    tag: <commit-id-cua-branch-dev_tax_service>
```

ArgoCD app `avocado2-dev` se sync vi app dev theo doi branch `main`. Khi config nay duoc merge sang branch `staging`, app `avocado2-staging` se sync vao namespace `yas-staging`.

## Parameters chinh

| Parameter | Default | Mo ta |
| --- | --- | --- |
| `SOURCE_REPO_URL` | `https://github.com/ducquan19/yas.git` | Source repo dung de resolve branch thanh commit id. |
| `TAX_SERVICE_BRANCH` | `main` | Branch/tag cua tax service. |
| `ORDER_SERVICE_BRANCH` | `main` | Branch/tag cua order service. |
| `PRODUCT_SERVICE_BRANCH` | `main` | Branch/tag cua product service. |
| `SEARCH_SERVICE_BRANCH` | `main` | Branch/tag cua search service. |
| `CUSTOMER_SERVICE_BRANCH` | `main` | Branch/tag cua customer service. |
| `STOREFRONT_BRANCH` | `main` | Branch/tag cua storefront. |

Co the them parameter cho cac service con lai neu can test doc lap.

## Release len staging

Khi da test xong tren dev:

```bash
git checkout staging
git merge main
git push origin staging
```

ArgoCD staging apps co `targetRevision: staging`, nen staging chi deploy khi branch `staging` thay doi.
