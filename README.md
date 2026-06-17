# YAS GitOps CD

Repository này dùng để quản lý phần CD cho project **YAS: Yet Another Shop** trong đồ án DevOps. Mục tiêu là deploy các microservice lên nhiều Kubernetes cluster bằng GitOps/ArgoCD, cho phép developer chọn branch của từng service để test nhanh, và có job cleanup để xóa môi trường test.

## Deliverables trong repo

| Hạng mục | File/thư mục | Ghi chú |
| --- | --- | --- |
| ArgoCD multi-cluster | `argocd/project.yaml`, `argocd/applications/*.yaml` | Mỗi Application trỏ tới một cluster và một values file riêng. |
| Helm values theo cluster | `helm/yas/values-*.yaml` | Chia service theo từng cluster, tag mặc định là `main`. |
| Developer CD job | `jenkins/Jenkinsfile.developer_build` | Developer nhập branch/tag cho từng service. Cần chỉnh tiếp nếu muốn Jenkins chỉ commit GitOps và để ArgoCD sync. |
| Cleanup job | `jenkins/Jenkinsfile.cleanup`, `docs/cleanup.md` | Tài liệu đã mô tả luồng cleanup; Jenkinsfile hiện đang trống. |
| Hướng dẫn truy cập NodePort | `docs/tailscale-nodeport.md` | Dùng Tailscale IP hoặc worker node IP + NodePort. |
| Service mesh | `docs/service-mesh.md` | Checklist mTLS, AuthorizationPolicy, retry và bằng chứng test. |

## Kiến trúc mục tiêu

```text
Developer chọn branch trên Jenkins developer_build
        |
        v
Jenkins resolve branch -> image tag đã được CI build/push
        |
        v
Jenkins update values file đúng cluster trong GitOps repo
        |
        v
Git commit + push
        |
        v
ArgoCD detect thay đổi và sync từng Application
        |
        v
Kubernetes multi-cluster expose service bằng NodePort
```

## Tài liệu

- [Phân bổ service theo cluster](docs/service-distribution.md)
- [Thiết lập ArgoCD](docs/argocd-setup.md)
- [Luồng developer_build](docs/developer-build-flow.md)
- [Cleanup deployment](docs/cleanup.md)
- [Truy cập bằng Tailscale và NodePort](docs/tailscale-nodeport.md)
- [Service mesh và test plan](docs/service-mesh.md)
- [Quy ước đặt tên](docs/naming-conventions.md)
