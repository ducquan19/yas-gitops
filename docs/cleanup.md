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

---

## Developer Build Cleanup Job

Job này (`jenkins/Jenkinsfile.cleanup_dev`) dùng để xóa / reset các triển khai thử nghiệm của developer được tạo ra bởi `developer_build`.

### Cơ chế hoạt động
Thay vì tác động trực tiếp vào Kubernetes cluster bằng `kubectl`, job này hoạt động thông qua GitOps:
1. Reset tag của các service được chọn trong file `helm/yas/values-*.yaml` về `"main"`.
2. Commit và push thay đổi lên Git repository.
3. ArgoCD tự động nhận biết thay đổi và đồng bộ (sync) kéo các service về image tag ổn định (`main`).

### Hyperlink từ `developer_build`
Sau khi chạy thành công job `developer_build`, ở phần mô tả của build (Build description) và trong Console Log sẽ xuất hiện một đường dẫn hyperlink động.
Khi nhấp vào liên kết này, Jenkins sẽ tự động mở trang chạy job `developer_build_cleanup` và truyền sẵn các tham số (ví dụ `CLEANUP_MODE=SELECTIVE`, `DRY_RUN=false`, `CONFIRM=true` cùng với danh sách các service cần reset dựa trên build vừa rồi) giúp người dùng thực hiện cleanup nhanh chóng và an toàn.
