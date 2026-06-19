# YAS GitOps CD

Repository nay dung de quan ly phan CD cho project **YAS: Yet Another Shop** bang GitOps/ArgoCD.

ArgoCD hien handle hai moi truong:

- `dev`: branch `main`, namespace `yas-dev`
- `staging`: branch `staging`, namespace `yas-staging`

Jenkins khong deploy truc tiep len Kubernetes. Jenkins cap nhat values file trong GitOps repo, commit va push; ArgoCD detect thay doi va sync Application tuong ung.

## Deliverables trong repo

| Hang muc | File/thu muc | Ghi chu |
| --- | --- | --- |
| ArgoCD project | `argocd/project.yaml` | Cho phep deploy vao `yas-dev` va `yas-staging` tren cac cluster dich. |
| ArgoCD applications | `argocd/applications/*.yaml` | Moi cluster co Application rieng cho `dev` va `staging`. |
| Helm values theo cluster | `helm/yas/values-tdquan.yaml`, `values-tbnguyen274.yaml`, `values-avocado2.yaml`, `values-nqthang.yaml` | Chia service subset theo cluster. |
| Helm values theo environment | `helm/yas/values-dev.yaml`, `helm/yas/values-staging.yaml` | Chua config override rieng cho moi truong. |
| Developer CD job | `jenkins/Jenkinsfile.developer_build` | Developer chon branch/tag cho tung service; Jenkins update `main` de ArgoCD deploy dev. |
| ArgoCD bootstrap jobs | `jenkins/Jenkinsfile.argocd_install`, `Jenkinsfile.argocd_cluster_register`, `Jenkinsfile.argocd_apps_apply` | Cai ArgoCD, register clusters, apply AppProject/Application. |
| Cleanup job | `jenkins/Jenkinsfile.cleanup`, `docs/cleanup.md` | Tai lieu mo ta luong cleanup. |
| Huong dan truy cap NodePort | `docs/tailscale-nodeport.md` | Dung Tailscale IP hoac worker node IP + NodePort. |
| Service mesh | `docs/service-mesh.md` | Checklist mTLS, AuthorizationPolicy, retry va bang chung test. |

## Kien truc muc tieu

```text
Developer chon branch tren Jenkins developer_build
        |
        v
Jenkins resolve branch -> image tag da duoc CI build/push
        |
        v
Jenkins update values-<cluster>.yaml tren branch main
        |
        v
Git commit + push
        |
        v
ArgoCD dev detect thay doi tren main va sync namespace yas-dev
        |
        v
Release ready: merge main/tag config sang branch staging
        |
        v
ArgoCD staging detect thay doi tren staging va sync namespace yas-staging
        |
        v
Kubernetes multi-cluster expose service bang NodePort
```

## ArgoCD model

Moi Application dung chung chart `helm/yas` va ghep values theo thu tu:

```text
values.yaml
values-<cluster>.yaml
values-<environment>.yaml
```

Vi du:

- `tdquan-dev`: `targetRevision: main`, namespace `yas-dev`
- `tdquan-staging`: `targetRevision: staging`, namespace `yas-staging`

## Tai lieu

- [Phan bo service theo cluster va environment](docs/service-distribution.md)
- [Thiet lap ArgoCD](docs/argocd-setup.md)
- [Luong developer_build](docs/developer-build-flow.md)
- [Jenkins jobs dung kubeconfig](docs/jenkins-kubeconfig-jobs.md)
- [Cleanup deployment](docs/cleanup.md)
- [Truy cap bang Tailscale va NodePort](docs/tailscale-nodeport.md)
- [Service mesh va test plan](docs/service-mesh.md)
- [Quy uoc dat ten](docs/naming-conventions.md)
