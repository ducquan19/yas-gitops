# ArgoCD Setup

Mục tiêu của phần nâng cao là dùng ArgoCD để deploy GitOps cho nhiều cluster. Jenkins không nên deploy trực tiếp lên cluster trong luồng GitOps chuẩn; Jenkins chỉ cập nhật Git repo, ArgoCD sẽ sync.

## Thành phần

| File | Vai trò |
| --- | --- |
| `argocd/project.yaml` | Định nghĩa AppProject `yas`, source repo và các destination cluster được phép deploy. |
| `argocd/applications/tdquan.yaml` | Application cho cluster `tdquan`, dùng `values-tdquan.yaml`. |
| `argocd/applications/tbnguyen274.yaml` | Application cho cluster `tbnguyen274`, dùng `values-tbnguyen274.yaml`. |
| `argocd/applications/avocado2.yaml` | Application cho cluster `avocado2`, dùng `values-avocado2.yaml`. |
| `argocd/applications/nqthang.yaml` | Application cho cluster `nqthang`, dùng `values-nqthang.yaml`. |

## Điều kiện trước khi apply

- ArgoCD đã được cài trong namespace `argocd`.
- Các cluster đích đã được add vào ArgoCD.
- `repoURL` trong manifest trỏ đúng GitOps repository.
- Helm chart trong `helm/yas` render được Kubernetes manifest hợp lệ.
- Namespace đích là `yas`.

## Apply ArgoCD resources

```bash
kubectl apply -f argocd/project.yaml
kubectl apply -f argocd/applications/
```

Kiểm tra:

```bash
kubectl -n argocd get app
argocd app list
argocd app get tdquan
argocd app get tbnguyen274
argocd app get avocado2
argocd app get nqthang
```

## Sync policy

Các Application đang bật:

- `automated.prune=true`: xóa resource không còn trong Git.
- `automated.selfHeal=true`: tự sửa drift nếu cluster bị thay đổi ngoài Git.
- `CreateNamespace=true`: tạo namespace `yas` nếu chưa có.
