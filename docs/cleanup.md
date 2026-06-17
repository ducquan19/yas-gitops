# Cleanup Job

Theo đề bài cần có Jenkins job để xóa phần deploy của mục `developer_build`. Job này nên xóa môi trường test theo namespace hoặc release/application tương ứng.

## Mục tiêu

- Xóa deployment developer đã tạo.
- Giải phóng resource trong cluster.
- Để lại log và link để reviewer thấy cleanup đã chạy.

## Luồng cleanup khuyến nghị với ArgoCD

```text
1. Developer hoặc reviewer chạy Jenkins job cleanup.
2. Jenkins nhận namespace/app/cluster cần cleanup.
3. Jenkins revert tag values về main hoặc disable service test.
4. Jenkins commit và push GitOps repo.
5. ArgoCD prune/selfHeal để đưa cluster về trạng thái mong muốn.
```

Nếu muốn xóa toàn bộ namespace test:

```bash
kubectl delete namespace yas
```

Nhưng với GitOps, nếu ArgoCD app vẫn còn desired state, ArgoCD có thể tạo lại resource. Cách sạch hơn là:

- Xóa/sửa desired state trong Git.
- Để ArgoCD prune resource.
- Chỉ dùng `kubectl delete` khi cần cleanup khẩn cấp.

## Parameters nên có cho Jenkins cleanup

| Parameter | Default | Mô tả |
| --- | --- | --- |
| `NAMESPACE` | `yas` | Namespace cần cleanup. |
| `TARGET_CLUSTER` | `all` | Cluster cần cleanup hoặc `all`. |
| `CLEANUP_MODE` | `reset-tags` | `reset-tags`, `disable-service`, hoặc `delete-namespace`. |

## Bằng chứng cần chụp cho báo cáo

- Trang Jenkins cleanup job.
- Console log cleanup thành công.
- ArgoCD sync/prune sau cleanup.
- `kubectl get pods -n yas` cho thấy resource đã reset/xóa theo mode.

## Trạng thái repo

`jenkins/Jenkinsfile.cleanup` và `scripts/cleanup.sh` hiện đang trống. Cần bổ sung logic cleanup trước khi demo.
