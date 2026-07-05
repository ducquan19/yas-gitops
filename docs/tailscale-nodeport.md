# Tailscale và NodePort

Đề bài yêu cầu sau khi deploy phải cung cấp `domain name:port` dạng NodePort để developer truy cập test. Vì không có DNS thật, developer có thể dùng Tailscale IP của worker node hoặc tự thêm hostname vào file `hosts`.

## Lấy NodePort

Trên cluster đích:

```bash
kubectl -n yas get svc
kubectl -n yas get svc <service-name> -o wide
```

Nếu service là NodePort, output sẽ có dạng:

```text
NAME        TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)
storefront  NodePort   10.43.10.100    <none>        80:30080/TCP
```

URL truy cập:

```text
http://<worker-node-ip>:30080
```

Với Tailscale:

```text
http://<tailscale-ip>:30080
```

## Thêm hostname local

Trên máy developer, thêm vào file hosts:

Windows:

```text
C:\Windows\System32\drivers\etc\hosts
```

Linux/macOS:

```text
/etc/hosts
```

Vi du:

```text
100.65.39.31 yas-dev.local
```

Sau đó truy cập:

```text
http://yas-dev.local:<node-port>
```

## Mapping IP hiện trong ArgoCD

| ArgoCD app | Cluster server |
| --- | --- |
| `tdquan` | `https://100.91.182.4:53567` |
| `tbnguyen274` | `https://100.84.105.114:8443` |
| `nqthang` | `https://100.122.97.48:32801` |
| `avocado2` | `https://100.65.39.31:50983` |

Lưu ý: địa chỉ server của Kubernetes API không nhất thiết là NodePort access IP. Khi demo cần xác nhận IP worker node/Tailscale node đang expose NodePort.
