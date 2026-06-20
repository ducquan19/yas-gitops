# Cleanup Job

Cleanup job dung kubeconfig cua cac cluster de xu ly cac tac vu van hanh sau deploy.

Deploy chinh van di qua GitOps:

```text
Jenkins update Git -> ArgoCD sync -> Kubernetes
```

Cleanup truc tiep bang `kubectl` chi nen dung cho tinh huong van hanh, demo, hoac don resource loi.

## Jenkins Job

File:

```text
jenkins/Jenkinsfile.cleanup
```

Credential Secret file can co:

```text
tdquan-kubeconfig
tbnguyen274-kubeconfig
avocado2-kubeconfig
nqthang-kubeconfig
```

## Parameters

| Parameter | Default/values | Mo ta |
| --- | --- | --- |
| `TARGET_ENV` | `dev`, `staging` | Moi truong can cleanup. |
| `TARGET_CLUSTER` | `all`, `tdquan`, `tbnguyen274`, `avocado2`, `nqthang` | Cluster can cleanup. |
| `CLEANUP_MODE` | `delete-failed-pods`, `delete-namespace` | Tac vu cleanup. |
| `CONFIRM_CLEANUP` | `false` | Phai check truoc khi job chay. |

## Modes

`delete-failed-pods`:

```text
Xoa cac pod Failed trong namespace yas-dev hoac yas-staging.
```

`delete-namespace`:

```text
Xoa toan bo namespace yas-dev hoac yas-staging.
```

`delete-namespace` la tac vu pha huy. Neu ArgoCD Application van ton tai va automated sync dang bat, ArgoCD co the tao lai namespace/resource theo desired state trong Git.

## Evidence cho bao cao

- Jenkins cleanup job console log.
- Output `kubectl get namespace`.
- Output `kubectl get pods -n yas-dev` hoac `kubectl get pods -n yas-staging`.
- Trang ArgoCD cho thay app da sync/self-heal neu namespace bi tao lai.
