# ArgoCD Setup From Scratch

Muc tieu:

```text
Developer test -> Jenkins update main -> ArgoCD deploy dev
Release ready  -> merge main/tag config sang staging branch
               -> ArgoCD deploy staging
```

ArgoCD quan ly hai moi truong:

- `dev`: theo branch `main`, namespace `yas-dev`
- `staging`: theo branch `staging`, namespace `yas-staging`

## 1. Jenkins credentials

Tao 4 Secret file credentials cho kubeconfig:

| Credential ID | Cluster |
| --- | --- |
| `tdquan-kubeconfig` | `tdquan` |
| `tbnguyen274-kubeconfig` | `tbnguyen274` |
| `avocado2-kubeconfig` | `avocado2` |
| `nqthang-kubeconfig` | `nqthang` |

Sau khi cai ArgoCD va lay duoc admin password, tao them Username/password credential:

| Credential ID | Username | Password |
| --- | --- | --- |
| `argocd-admin` | `admin` | Initial/current ArgoCD admin password |

## 2. Cai ArgoCD

Tao Jenkins Pipeline job tro toi:

```text
jenkins/Jenkinsfile.argocd_install
```

Parameters:

| Parameter | Goi y |
| --- | --- |
| `TARGET_ARGOCD_CLUSTER` | Chon cluster de cai ArgoCD, vi du `tdquan`. |
| `ARGOCD_NAMESPACE` | `argocd` |
| `ARGOCD_INSTALL_URL` | `https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml` |
| `ARGOCD_SERVER_SERVICE_TYPE` | `NodePort` neu can truy cap tu ngoai cluster; `ClusterIP` neu chi dung port-forward. |
| `PRINT_INITIAL_ADMIN_PASSWORD` | `false` mac dinh; bat `true` neu chap nhan password xuat hien trong Jenkins log. |

Job nay chay:

```text
kubectl create namespace argocd
kubectl apply -n argocd -f <ARGOCD_INSTALL_URL>
kubectl rollout status ...
kubectl patch svc argocd-server type=<ARGOCD_SERVER_SERVICE_TYPE>
```

Neu khong in password trong Jenkins log, lay password tren may co kubectl:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

Dang nhap:

```bash
argocd login <ARGOCD_SERVER> --username admin --password <password> --insecure
```

Sau do tao Jenkins credential `argocd-admin`.

## 3. Tao branch staging

Staging apps theo doi branch `staging`, nen branch nay phai ton tai:

```bash
git checkout -b staging
git push origin staging
git checkout main
```

Neu branch da ton tai:

```bash
git fetch origin
git checkout staging
git pull
git checkout main
```

## 4. Register 4 clusters vao ArgoCD

Tao Jenkins Pipeline job tro toi:

```text
jenkins/Jenkinsfile.argocd_cluster_register
```

Parameters:

| Parameter | Goi y |
| --- | --- |
| `ARGOCD_SERVER` | Dia chi ArgoCD server, vi du `<tailscale-ip>:<nodeport>` hoac DNS. |
| `ARGOCD_CREDENTIALS_ID` | `argocd-admin` |
| `INSECURE_ARGOCD_TLS` | `true` neu dung self-signed/default cert. |

Job nay dung 4 kubeconfig secret files de chay:

```text
argocd cluster add <context> --name tdquan
argocd cluster add <context> --name tbnguyen274
argocd cluster add <context> --name avocado2
argocd cluster add <context> --name nqthang
```

Kiem tra:

```bash
argocd cluster list
```

## 5. Apply AppProject va Applications

Tao Jenkins Pipeline job tro toi:

```text
jenkins/Jenkinsfile.argocd_apps_apply
```

Parameters:

| Parameter | Goi y |
| --- | --- |
| `TARGET_ARGOCD_CLUSTER` | Cluster da cai ArgoCD. |
| `ARGOCD_NAMESPACE` | `argocd` |

Job nay apply:

```bash
kubectl apply -f argocd/project.yaml
kubectl apply -f argocd/applications/
```

## 6. Mo hinh Application

Moi Application dung chung chart `helm/yas`, nhung ghep values theo thu tu:

```text
values.yaml
values-<cluster>.yaml
values-<environment>.yaml
```

Vi du `tdquan-dev`:

```yaml
targetRevision: main
helm:
  valueFiles:
    - values.yaml
    - values-tdquan.yaml
    - values-dev.yaml
destination:
  namespace: yas-dev
```

Vi du `tdquan-staging`:

```yaml
targetRevision: staging
helm:
  valueFiles:
    - values.yaml
    - values-tdquan.yaml
    - values-staging.yaml
destination:
  namespace: yas-staging
```

## 7. Test dev flow

Chay Jenkins job:

```text
jenkins/Jenkinsfile.developer_build
```

Nhap branch cho service can test. Jenkins update values tren branch `main`, ArgoCD app `*-dev` sync vao `yas-dev`.

Kiem tra bang:

```text
jenkins/Jenkinsfile.cluster_health_check
jenkins/Jenkinsfile.nodeport_report
```

## 8. Release staging

Khi dev on dinh:

```bash
git checkout staging
git merge main
git push origin staging
```

Sau khi branch `staging` thay doi, cac Application `*-staging` sync vao namespace `yas-staging`.
