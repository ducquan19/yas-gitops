# Hoàn thiện Dynamic Helm Chart cho hệ thống YAS

Mình đã hoàn thành việc triển khai kiến trúc Dynamic Helm Chart dựa trên danh sách task bạn yêu cầu. Kiến trúc này giúp bạn dễ dàng quản lý một số lượng lớn các Microservices (như YAS) mà không gặp tình trạng trùng lặp mã (Boilerplate code).

## Những thay đổi chính

### 1. Kiến trúc Template Lặp (Range Loop)
Thay vì tạo 14 file riêng lẻ, mình đã sử dụng vòng lặp `{{- range $serviceName, $serviceConfig := .Values }}` cho toàn bộ thư mục `templates/`.
- [deployment.yaml](file:///d:/github/yas-gitops/helm/yas/templates/deployment.yaml)
- [service.yaml](file:///d:/github/yas-gitops/helm/yas/templates/service.yaml)
- [configmap.yaml](file:///d:/github/yas-gitops/helm/yas/templates/configmap.yaml)
- [secret.yaml](file:///d:/github/yas-gitops/helm/yas/templates/secret.yaml)

Các file này tự động nhận diện service nào được đánh dấu `enabled: true` trong values để khởi tạo. Bạn hoàn toàn có thể ghi đè image tag, cấu hình resource, và namespace thông qua Helm CLI hoặc file config riêng của cluster (như `values-tdquan.yaml`).

### 2. Cấu hình Values mặc định (Base Values)
Mình đã xây dựng xong cấu trúc chuẩn cho **14 services** trong file gốc:
- [values.yaml](file:///d:/github/yas-gitops/helm/yas/values.yaml)

Tại đây:
- Mỗi service (ví dụ: `storefront`, `tax`, `cart`...) được thiết lập mặc định `enabled: false`.
- **Resource limit/request:** Được gán mặc định (256Mi - 512Mi / 100m - 500m) để chống quá tải RAM/CPU cho các Node K8s.
- **Image/Tag:** Dùng chuẩn `ducquan19/<tên_service>:main` mặc định, sẵn sàng để luồng CI/CD Jenkins thay thế.
- **NodePort:** Mỗi service đã được khai báo loại `type: NodePort` và gán tĩnh một `nodePort` khác nhau trải từ `30001` đến `30014`, giúp cho Developer truy cập trực tiếp cực kỳ tiện lợi để debug.

### 3. Kết quả Kiểm thử (Verification)
Chạy thử lệnh `helm template` với override file `values-tdquan.yaml` cho kết quả **thành công 100%**:
- Những service nào được `enabled: true` trong `values-tdquan.yaml` (như `cart`, `order`, `tax`...) đều được render YAML chuẩn.
- Các service đang `false` ở bản gốc tự động bị lược bỏ đi.

## Bước tiếp theo dành cho bạn
Hệ thống K8s/Helm Chart đã ổn định và sẵn sàng. 
Bạn có thể tiếp tục tiến hành test thử một luồng Pipeline Jenkins (`developer_build`) để xác minh GitOps ArgoCD bắt sự thay đổi của Helm này thành công nhé!

---

## Phụ lục: Giải thích cơ chế "Vòng lặp" (Range Loop) hoạt động

### 1. Vấn đề của cách làm cũ (Static Chart)
Thông thường, nếu bạn có 14 microservices (như `cart`, `order`, `tax`...), bạn sẽ phải tạo ra 14 file `deployment.yaml` khác nhau:
- `templates/cart-deployment.yaml`
- `templates/order-deployment.yaml`
- `templates/tax-deployment.yaml`
- ...

Cách làm này có nhược điểm cực lớn:
- **Trùng lặp mã (Boilerplate):** Nội dung các file này giống hệt nhau tới 90% (đều có apiVersion, kind, metadata, resources...), chỉ khác mỗi tên service và image tag.
- **Khó bảo trì:** Giả sử bạn muốn đổi cấu hình port chuẩn cho tất cả từ `8080` sang `3000`, bạn sẽ phải mở bằng tay 14 file ra để sửa.
- **Khó thêm mới:** Mở rộng thêm service thứ 15 đồng nghĩa với việc phải copy-paste thêm một file nữa.

### 2. Giải pháp: Sử dụng "Vòng lặp" (Range Loop) trong Helm
Helm template được xây dựng dựa trên ngôn ngữ template của Go (Go templates). Nó cho phép bạn sử dụng các lệnh lập trình cơ bản như `if/else` và vòng lặp `range`.

Thay vì tạo 14 file, chúng ta chỉ tạo **đúng 1 file** `templates/deployment.yaml`. Trong file này, chúng ta đặt một vòng lặp ở ngay dòng đầu tiên:

```gotemplate
{{- range $serviceName, $serviceConfig := .Values }}
```

**Câu lệnh này có nghĩa là:**
Hãy nhìn vào file `values.yaml` gốc. Quét qua tất cả các khối cấu hình cấp cao nhất bên trong đó. Mỗi lần lặp qua một khối cấu hình, hãy gán:
- Tên của khối đó vào biến `$serviceName` (ví dụ vòng lặp đầu tiên: `$serviceName` = `cart`).
- Toàn bộ nội dung thông số bên trong khối đó vào biến `$serviceConfig` (chứa các thông tin như `enabled`, `image`, `resources`).

Bên trong vòng lặp, chúng ta sử dụng **các câu lệnh điều kiện (if)** để lọc:

```gotemplate
{{- if typeIs "map[string]interface {}" $serviceConfig }}
{{- if hasKey $serviceConfig "enabled" }}
{{- if eq $serviceConfig.enabled true }}
```
**Ý nghĩa của 3 dòng này:**
1. Chỉ lấy những cấu hình có dạng Map (bỏ qua những biến chuỗi hoặc số rời rạc không phải là service).
2. Kiểm tra xem cấu hình đó có chứa từ khoá `enabled` hay không.
3. (Quan trọng nhất) Kiểm tra xem `enabled` có đang được set là `true` hay không.

### 3. Điều kỳ diệu khi Helm Render (Sinh ra YAML)
Nếu một service thỏa mãn 3 điều kiện trên (được bật là `true`), Helm sẽ "nhỏ giọt" (render) đoạn YAML cấu hình Deployment cho riêng service đó và thay các biến bằng giá trị thực tế:

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $serviceName }} # Thay bằng "cart", "order"...
```

Sau khi sinh xong Deployment cho `cart`, vòng lặp quay lại từ đầu và tiếp tục xét tới `order`, rồi tới `tax`... Kết quả là Helm sẽ tự động nhân bản đoạn code chuẩn của bạn thành nhiều khối Deployment nằm chung trong 1 luồng output duy nhất (ngăn cách nhau bởi ký hiệu `---`). 

### 4. Tóm lại, lợi ích của kiến trúc này là gì?
- **DRY (Don't Repeat Yourself):** Code Helm cực kỳ ngắn gọn và tập trung. Muốn đổi port hay thêm biến môi trường, chỉ cần sửa 1 chỗ duy nhất.
- **Dễ dàng kiểm soát môi trường bằng GitOps:** File template đứng im không đổi. Thứ thay đổi duy nhất là file `values-<cluster>.yaml`.
- Developer/Jenkins chỉ cần việc nhảy vào file `values` và đánh dấu `enabled: true`, là resource đó sẽ tự động "xuất hiện" trên cluster K8s. Cực kỳ động (Dynamic)!
