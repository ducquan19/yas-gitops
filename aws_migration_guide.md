# 🚀 Hướng Dẫn Migration YAS lên AWS

> **Phiên bản phân tích:** Dựa trên codebase `yas/` và `yas-gitops/` thực tế.  
> **Kiến trúc hiện tại:** Multi-cluster qua Tailscale (local K8s) → **Mục tiêu:** AWS EKS + Managed Services

---

## 📋 Mục Lục

1. [Tổng Quan Kiến Trúc Hiện Tại](#1-tổng-quan-kiến-trúc-hiện-tại)
2. [Kiến Trúc AWS Đề Xuất](#2-kiến-trúc-aws-đề-xuất)
3. [Danh Sách Công Việc (Checklist)](#3-danh-sách-công-việc-checklist)
4. [Phase 1 – Chuẩn Bị Nền Tảng AWS](#phase-1--chuẩn-bị-nền-tảng-aws)
5. [Phase 2 – Deploy Jenkins trên AWS](#phase-2--deploy-jenkins-trên-aws)
6. [Phase 3 – Xây Dựng EKS Cluster](#phase-3--xây-dựng-eks-cluster)
7. [Phase 4 – Deploy ArgoCD](#phase-4--deploy-argocd)
8. [Phase 5 – Deploy Infrastructure (Kafka, PostgreSQL, Redis, Elasticsearch, Keycloak)](#phase-5--deploy-infrastructure)
9. [Phase 6 – Deploy Microservices YAS](#phase-6--deploy-microservices-yas)
10. [Phase 7 – Deploy Observability Stack](#phase-7--deploy-observability-stack)
11. [Phase 8 – Thay Đổi Source Code & Cấu Hình](#phase-8--thay-đổi-source-code--cấu-hình)
12. [Phase 9 – Networking & Domain](#phase-9--networking--domain)
13. [Phase 10 – CI/CD Pipeline Hoàn Chỉnh](#phase-10--cicd-pipeline-hoàn-chỉnh)
14. [Chi Phí Ước Tính](#chi-phí-ước-tính)
15. [Checklist Tổng Hợp](#checklist-tổng-hợp)

---

## 1. Tổng Quan Kiến Trúc Hiện Tại

### Hệ thống YAS hiện tại bao gồm:

| Thành phần | Local (Hiện tại) | AWS (Mục tiêu) |
|---|---|---|
| **Kubernetes** | Minikube / K3s qua Tailscale VPN | Amazon EKS (Managed) |
| **CI/CD** | Jenkins chạy trên local VM | Jenkins trên EC2 hoặc EKS |
| **GitOps** | ArgoCD trên cluster local | ArgoCD trên EKS |
| **Container Registry** | Docker Hub (`ducquan19/*`) | Amazon ECR |
| **Database** | PostgreSQL StatefulSet (K8s) | Amazon RDS (PostgreSQL) hoặc K8s |
| **Message Queue** | Kafka StatefulSet (K8s) | Amazon MSK hoặc K8s |
| **Cache** | Redis StatefulSet (K8s) | Amazon ElastiCache hoặc K8s |
| **Search** | Elasticsearch StatefulSet (K8s) | Amazon OpenSearch hoặc K8s |
| **IAM** | Keycloak StatefulSet (K8s) | Keycloak trên EKS (giữ nguyên) |
| **Ingress** | Nginx NodePort (30090) | AWS ALB + Nginx Ingress Controller |
| **DNS** | `/etc/hosts` trên local | Route 53 |
| **TLS/SSL** | Không có | AWS ACM (Certificate Manager) |
| **Observability** | Prometheus + Grafana + Loki + Tempo + Kiali | Giữ nguyên stack trên EKS |
| **Service Mesh** | Istio (optional) | Istio trên EKS |
| **Networking** | Tailscale VPN giữa 2 cluster | AWS VPC (single cluster) |

### Microservices hiện có:
- **Frontend:** `storefront-nextjs`, `backoffice-nextjs`, `swagger`
- **BFF (Spring Cloud Gateway):** `storefront-bff`, `backoffice-bff`
- **Backend:** `product`, `cart`, `order`, `customer`, `inventory`, `media`, `search`, `tax`, `location`, `payment`, `sampledata`
- **Infrastructure:** PostgreSQL, Kafka, Zookeeper, Redis, Elasticsearch, Keycloak

---

## 2. Kiến Trúc AWS Đề Xuất

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         AWS Cloud (us-east-1)                           │
│                                                                         │
│  ┌─────────────┐     ┌─────────────────────────────────────────────┐   │
│  │  Route 53   │────▶│           AWS ALB (Load Balancer)           │   │
│  │ *.yas.io    │     └──────────────────┬──────────────────────────┘   │
│  └─────────────┘                        │                               │
│                                         ▼                               │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                  Amazon EKS Cluster (Single)                    │    │
│  │                                                                │    │
│  │  Namespace: argocd         Namespace: infrastructure           │    │
│  │  ┌─────────────┐           ┌─────────────────────────────┐    │    │
│  │  │   ArgoCD    │           │  Keycloak | Kafka | Redis    │    │    │
│  │  │  (GitOps)   │           │  Elasticsearch | PostgreSQL  │    │    │
│  │  └─────────────┘           └─────────────────────────────┘    │    │
│  │                                                                │    │
│  │  Namespace: yas-prod                                           │    │
│  │  ┌────────────────────────────────────────────────────────┐   │    │
│  │  │ storefront-nextjs │ backoffice-nextjs │ swagger        │   │    │
│  │  │ storefront-bff    │ backoffice-bff                     │   │    │
│  │  │ product │ cart │ order │ customer │ inventory          │   │    │
│  │  │ media │ search │ tax │ location │ payment │ sampledata │   │    │
│  │  └────────────────────────────────────────────────────────┘   │    │
│  │                                                                │    │
│  │  Namespace: observability                                      │    │
│  │  ┌──────────────────────────────────────────────────────┐     │    │
│  │  │ Prometheus │ Grafana │ Loki │ Tempo │ Kiali          │     │    │
│  │  │ OpenTelemetry Collector                               │     │    │
│  │  └──────────────────────────────────────────────────────┘     │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                         │
│  ┌─────────────────────┐    ┌────────────────────┐                     │
│  │   EC2 (Jenkins)     │    │   Amazon ECR        │                     │
│  │   t3.large          │───▶│   (Docker Registry) │                     │
│  │   CI/CD Pipeline    │    │                    │                     │
│  └─────────────────────┘    └────────────────────┘                     │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────┐       │
│  │                    AWS VPC (10.0.0.0/16)                    │       │
│  │  Public Subnet (10.0.1.0/24)  │  Private Subnet (10.0.2.0) │       │
│  │  - ALB, NAT Gateway, Jenkins  │  - EKS nodes, RDS (opt.)   │       │
│  └─────────────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Danh Sách Công Việc (Checklist)

### Phase 1 – AWS Foundation
- [ ] Tạo AWS Account & cấu hình IAM Users/Roles
- [ ] Tạo VPC với Public/Private Subnets
- [ ] Cấu hình Security Groups
- [ ] Cài AWS CLI & kubectl & eksctl & helm

### Phase 2 – Jenkins
- [ ] Launch EC2 t3.large cho Jenkins
- [ ] Cài Jenkins + plugins
- [ ] Cấu hình credentials (GitHub, ECR, EKS)
- [ ] Cập nhật Jenkinsfile dùng ECR thay Docker Hub

### Phase 3 – EKS Cluster
- [ ] Tạo EKS cluster bằng eksctl
- [ ] Cài Node Groups (On-Demand + Spot)
- [ ] Cài AWS Load Balancer Controller
- [ ] Cài Nginx Ingress Controller
- [ ] Cấu hình OIDC Provider cho IRSA

### Phase 4 – ArgoCD
- [ ] Deploy ArgoCD trên EKS
- [ ] Cấu hình ArgoCD với GitHub repo
- [ ] Cập nhật `argocd/project.yaml` (single cluster)
- [ ] Cập nhật `argocd/applications/*.yaml`

### Phase 5 – Infrastructure
- [ ] Deploy PostgreSQL (K8s StatefulSet hoặc RDS)
- [ ] Deploy Kafka + Zookeeper (K8s hoặc MSK)
- [ ] Deploy Redis (K8s hoặc ElastiCache)
- [ ] Deploy Elasticsearch (K8s hoặc OpenSearch)
- [ ] Deploy Keycloak (K8s)
- [ ] Import Keycloak Realm

### Phase 6 – Microservices
- [ ] Tạo ECR repositories cho từng service
- [ ] Push Docker images lên ECR
- [ ] Cập nhật `values.yaml` – đổi image repository sang ECR
- [ ] Cập nhật `values-aws.yaml` – bật tất cả services
- [ ] Deploy qua ArgoCD

### Phase 7 – Observability
- [ ] Deploy Prometheus + Grafana + Loki + Tempo + Kiali
- [ ] Cấu hình OpenTelemetry Collector
- [ ] Kiểm tra dashboards

### Phase 8 – Networking & Domain
- [ ] Tạo hosted zone trên Route 53
- [ ] Tạo SSL certificate trên ACM
- [ ] Cấu hình ALB Ingress với HTTPS
- [ ] Cập nhật environment variables trong các services

### Phase 9 – CI/CD Hoàn Chỉnh
- [ ] Test full pipeline: commit → Jenkins → ECR → ArgoCD → EKS
- [ ] Cấu hình webhook GitHub → Jenkins

---

## Phase 1 – Chuẩn Bị Nền Tảng AWS

### 1.1 Cài đặt công cụ

```bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install
aws configure  # nhập Access Key ID, Secret, region, output format

# eksctl
curl --silent --location "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 1.2 Tạo VPC & Networking

```bash
# Dùng AWS Console hoặc Terraform/CloudFormation
# Cấu hình tối thiểu:
# - VPC: 10.0.0.0/16
# - 2 Public Subnets: 10.0.1.0/24 (AZ-a), 10.0.2.0/24 (AZ-b)
# - 2 Private Subnets: 10.0.3.0/24 (AZ-a), 10.0.4.0/24 (AZ-b)
# - Internet Gateway, NAT Gateway

# Tags bắt buộc cho EKS ALB (thêm vào Subnets):
# Public Subnets:  kubernetes.io/role/elb = 1
# Private Subnets: kubernetes.io/role/internal-elb = 1
```

### 1.3 IAM Roles cần thiết

| Role | Mục đích |
|---|---|
| `eks-cluster-role` | EKS Control Plane |
| `eks-nodegroup-role` | EC2 worker nodes |
| `jenkins-role` | EC2 Jenkins: quyền ECR, EKS |
| `alb-controller-role` | AWS Load Balancer Controller (IRSA) |

---

## Phase 2 – Deploy Jenkins trên AWS

### 2.1 Launch EC2 Instance

```bash
# Specs: t3.large (2 vCPU, 8GB RAM), Ubuntu 22.04 LTS
# Volume: 50GB gp3
# Security Group:
#   - Inbound: 22 (SSH từ IP của bạn), 8080 (Jenkins UI), 50000 (JNLP agents)
#   - Outbound: All

# Sau khi SSH vào EC2:
sudo apt update && sudo apt install -y openjdk-17-jdk maven docker.io git

# Cài Jenkins
curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update && sudo apt install -y jenkins
sudo systemctl enable jenkins && sudo systemctl start jenkins

# Thêm jenkins user vào docker group
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins

# Cài kubectl & helm trên Jenkins EC2
# (dùng lệnh từ Phase 1.1)
```

### 2.2 Cấu hình Jenkins Credentials

Trong Jenkins UI → Manage Jenkins → Credentials → Add:

| Credential ID | Type | Nội dung |
|---|---|---|
| `github-creds` | Username/Password | GitHub Personal Access Token |
| `aws-credentials` | AWS Credentials | AWS Access Key + Secret |
| `ecr-credentials` | Username/Password | `AWS` / `$(aws ecr get-login-password)` |
| `snyk-quan` | Secret Text | Snyk API Token |
| `sonar-token` | Secret Text | SonarQube Token |

### 2.3 Cài Jenkins Plugins

Vào Manage Jenkins → Plugins, cài thêm:
- `Amazon ECR plugin`
- `AWS Credentials Plugin`
- `Pipeline AWS Steps`
- `Docker Pipeline`
- `Kubernetes plugin` (nếu dùng K8s agents)
- `SonarQube Scanner`
- `Coverage`
- `JUnit`

### 2.4 Cấp quyền Jenkins EC2 → ECR & EKS

```bash
# Gán IAM Role cho EC2 Jenkins instance với policies:
# - AmazonEC2ContainerRegistryFullAccess
# - AmazonEKSClusterPolicy (để kubectl apply)
# - Hoặc dùng OIDC + IRSA nếu Jenkins chạy trong EKS

# Update kubeconfig trên Jenkins EC2
aws eks update-kubeconfig --region us-east-1 --name yas-cluster
```

---

## Phase 3 – Xây Dựng EKS Cluster

### 3.1 Tạo EKS Cluster với eksctl

Tạo file `eks-cluster.yaml`:

```yaml
# eks-cluster.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: yas-cluster
  region: us-east-1
  version: "1.30"

iam:
  withOIDC: true  # Bắt buộc cho IRSA (ALB Controller, EBS CSI...)

managedNodeGroups:
  # Node group cho Infrastructure (Kafka, PostgreSQL...) - cần nhiều RAM
  - name: infra-nodegroup
    instanceType: t3.xlarge   # 4 vCPU, 16GB RAM
    minSize: 1
    maxSize: 3
    desiredCapacity: 2
    volumeSize: 50
    labels:
      role: infra
    privateNetworking: true

  # Node group cho Microservices
  - name: app-nodegroup
    instanceType: t3.large    # 2 vCPU, 8GB RAM
    minSize: 2
    maxSize: 6
    desiredCapacity: 3
    volumeSize: 30
    labels:
      role: app
    privateNetworking: true
    spot: true  # Tiết kiệm chi phí

  # Node group cho Observability
  - name: o11y-nodegroup
    instanceType: t3.large
    minSize: 1
    maxSize: 2
    desiredCapacity: 1
    volumeSize: 50
    labels:
      role: observability
    privateNetworking: true
```

```bash
eksctl create cluster -f eks-cluster.yaml
# Quá trình tạo mất ~15-20 phút

# Verify
kubectl get nodes
```

### 3.2 Cài AWS Load Balancer Controller

```bash
# Tạo IAM policy cho ALB Controller
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

# Tạo Service Account với IRSA
eksctl create iamserviceaccount \
  --cluster=yas-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::<ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

# Cài ALB Controller bằng Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=yas-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Cài Nginx Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace kube-system \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"=external \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"=internet-facing
```

### 3.3 Cài AWS EBS CSI Driver (Storage)

```bash
# Cần cho PersistentVolumes (PostgreSQL, Kafka, Elasticsearch...)
eksctl create addon --name aws-ebs-csi-driver --cluster yas-cluster \
  --service-account-role-arn arn:aws:iam::<ACCOUNT_ID>:role/AmazonEKS_EBS_CSI_DriverRole \
  --force
```

---

## Phase 4 – Deploy ArgoCD

### 4.1 Cài ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Expose ArgoCD UI (dùng LoadBalancer hoặc Ingress)
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Lấy mật khẩu admin
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

### 4.2 Cập nhật ArgoCD Project cho AWS (Single Cluster)

Sửa file `yas-gitops/argocd/project.yaml`:

```yaml
# argocd/project.yaml - AWS VERSION
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: yas
  namespace: argocd
spec:
  description: YAS GitOps project - AWS EKS single cluster

  sourceRepos:
    - https://github.com/<YOUR_ORG>/yas-gitops.git

  destinations:
    # EKS cluster - all namespaces
    - namespace: yas-prod
      server: https://kubernetes.default.svc
    - namespace: yas-dev
      server: https://kubernetes.default.svc
    - namespace: infrastructure
      server: https://kubernetes.default.svc
    - namespace: observability
      server: https://kubernetes.default.svc
    - namespace: argocd
      server: https://kubernetes.default.svc
    - namespace: kube-system
      server: https://kubernetes.default.svc

  clusterResourceWhitelist:
    - group: ""
      kind: Namespace
    - group: "*"
      kind: "*"

  namespaceResourceWhitelist:
    - group: "*"
      kind: "*"
```

### 4.3 Cập nhật ArgoCD Applications

Sửa `yas-gitops/argocd/applications/infra.yaml`:

```yaml
# argocd/applications/infra.yaml - AWS VERSION
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: infra
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  project: yas
  source:
    repoURL: https://github.com/<YOUR_ORG>/yas-gitops.git
    targetRevision: main
    path: helm/infra
  destination:
    server: https://kubernetes.default.svc
    namespace: infrastructure  # Giữ nguyên namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Tạo mới `yas-gitops/argocd/applications/yas-aws-appset.yaml`:

```yaml
# argocd/applications/yas-aws-appset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: yas-aws
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - env: prod
            namespace: yas-prod
          - env: dev
            namespace: yas-dev
  template:
    metadata:
      name: "yas-{{env}}"
    spec:
      project: yas
      source:
        repoURL: https://github.com/<YOUR_ORG>/yas-gitops.git
        targetRevision: main
        path: helm/yas
        helm:
          valueFiles:
            - values.yaml
            - "values-aws-{{env}}.yaml"
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{namespace}}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

---

## Phase 5 – Deploy Infrastructure

> **Lưu ý chiến lược:** Giữ nguyên Helm charts hiện tại (`helm/infra`) cho K8s deployment. Chỉ cần thêm `StorageClass` đúng cho EBS.

### 5.1 Cập nhật StorageClass cho EBS

Thêm vào `helm/infra/templates/` file `storageclass.yaml`:

```yaml
# helm/infra/templates/storageclass.yaml (NEW)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp3
  encrypted: "true"
```

### 5.2 Cập nhật PersistentVolumeClaim trong templates

Trong các templates PostgreSQL, Kafka, Elasticsearch, thêm `storageClassName: ebs-sc`:

```yaml
# Ví dụ trong helm/infra/templates/postgresql.yaml
# Tìm và thêm storageClassName vào PVC
spec:
  storageClassName: ebs-sc  # ← THÊM DÒNG NÀY
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 10Gi
```

### 5.3 Deploy Infrastructure qua ArgoCD

```bash
kubectl apply -f argocd/applications/infra.yaml
# Theo dõi trạng thái:
kubectl get pods -n infrastructure -w

# Các services cần chờ Ready:
# - infra-postgresql
# - infra-kafka
# - infra-redis
# - infra-elasticsearch
# - infra-keycloak
```

### 5.4 Import Keycloak Realm

```bash
# Port-forward đến Keycloak
kubectl port-forward svc/infra-keycloak -n infrastructure 8080:80

# Truy cập: http://localhost:8080/admin (admin/admin)
# Vào: Create Realm → Import file yas/identity/realm-export.json
```

---

## Phase 6 – Deploy Microservices YAS

### 6.1 Tạo ECR Repositories

```bash
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=us-east-1

# Danh sách services cần tạo ECR repo
SERVICES=(
  "yas-storefront"
  "yas-backoffice"
  "yas-storefront-bff"
  "yas-backoffice-bff"
  "yas-product"
  "yas-cart"
  "yas-order"
  "yas-customer"
  "yas-inventory"
  "yas-media"
  "yas-search"
  "yas-tax"
  "yas-location"
  "yas-payment"
  "yas-sampledata"
)

for SERVICE in "${SERVICES[@]}"; do
  aws ecr create-repository \
    --repository-name $SERVICE \
    --region $AWS_REGION \
    --image-scanning-configuration scanOnPush=true
  echo "Created ECR repo: $SERVICE"
done
```

### 6.2 Push Initial Images lên ECR

```bash
# Login ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Ví dụ với product service:
cd yas/product
docker build -t yas-product .
docker tag yas-product:latest \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/yas-product:latest
docker push \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/yas-product:latest
```

### 6.3 Tạo values-aws-prod.yaml

Tạo file `yas-gitops/helm/yas/values-aws-prod.yaml`:

```yaml
# helm/yas/values-aws-prod.yaml
# AWS Production environment - Single EKS Cluster

global:
  keycloak:
    # Sử dụng internal K8s DNS (giữ nguyên)
    issuerUri: http://infra-keycloak.infrastructure.svc.cluster.local/realms/Yas
  postgresql:
    username: admin
    password: admin  # ← Đổi sang AWS Secrets Manager trong production
  kafka:
    bootstrapServers: infra-kafka.infrastructure.svc.cluster.local:9092
  redis:
    host: infra-redis.infrastructure.svc.cluster.local
    port: 6379
  elasticsearch:
    uris: http://infra-elasticsearch.infrastructure.svc.cluster.local:9200

# ECR image prefix
_ecr_prefix: &ecr_prefix "<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com"

# --- BFF ---
storefront-bff:
  enabled: true
  image:
    repository: "<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/yas-storefront-bff"
    tag: latest
  service:
    type: ClusterIP  # ← Đổi từ NodePort sang ClusterIP (dùng Ingress)
  uiHost: "https://storefront.yas.io"

backoffice-bff:
  enabled: true
  image:
    repository: "<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/yas-backoffice-bff"
    tag: latest
  service:
    type: ClusterIP
  uiHost: "https://backoffice.yas.io"

# --- Frontend ---
storefront-nextjs:
  enabled: true
  image:
    repository: "<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/yas-storefront"
    tag: latest
  service:
    type: ClusterIP
  env:
    NEXT_PUBLIC_API_BASE_PATH: "https://storefront.yas.io"
    API_BASE_PATH: "http://storefront-bff:8082/api"

backoffice-nextjs:
  enabled: true
  image:
    repository: "<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/yas-backoffice"
    tag: latest
  service:
    type: ClusterIP
  env:
    NEXT_PUBLIC_API_BASE_PATH: "https://backoffice.yas.io"
    API_BASE_PATH: "http://backoffice-bff:8082/api"

# --- Swagger UI ---
swagger:
  enabled: true
  service:
    type: ClusterIP
  env:
    URLS: "[{ url: 'https://api.yas.io/product/v3/api-docs', name: 'Product' },{ url: 'https://api.yas.io/media/v3/api-docs', name: 'Media' },{ url: 'https://api.yas.io/customer/v3/api-docs', name: 'Customer' },{ url: 'https://api.yas.io/cart/v3/api-docs', name: 'Cart' },{ url: 'https://api.yas.io/order/v3/api-docs', name: 'Order' },{ url: 'https://api.yas.io/inventory/v3/api-docs', name: 'Inventory' },{ url: 'https://api.yas.io/location/v3/api-docs', name: 'Location' },{ url: 'https://api.yas.io/tax/v3/api-docs', name: 'Tax' },{ url: 'https://api.yas.io/search/v3/api-docs', name: 'Search' },{ url: 'https://api.yas.io/payment/v3/api-docs', name: 'Payment' }]"
    OAUTH_CLIENT_ID: "swagger-ui"
    OAUTH_USE_PKCE: "true"

# --- Backend Services ---
product:
  enabled: true
  image:
    repository: "<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/yas-product"
    tag: latest
  service:
    type: ClusterIP

cart:
  enabled: true
  image:
    repository: "<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/yas-cart"
    tag: latest
  service:
    type: ClusterIP

order:
  enabled: true
  image:
    repository: "<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/yas-order"
    tag: latest
  service:
    type: ClusterIP

customer:
  enabled: true
  image:
    repository: "<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/yas-customer"
    tag: latest
  service:
    type: ClusterIP

inventory:
  enabled: true
  image:
    repository: "<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/yas-inventory"
    tag: latest
  service:
    type: ClusterIP

media:
  enabled: true
  image:
    repository: "<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/yas-media"
    tag: latest
  service:
    type: ClusterIP

search:
  enabled: true
  image:
    repository: "<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/yas-search"
    tag: latest
  service:
    type: ClusterIP

tax:
  enabled: true
  image:
    repository: "<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/yas-tax"
    tag: latest
  service:
    type: ClusterIP

location:
  enabled: true
  image:
    repository: "<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/yas-location"
    tag: latest
  service:
    type: ClusterIP

payment:
  enabled: true
  image:
    repository: "<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/yas-payment"
    tag: latest
  service:
    type: ClusterIP

sampledata:
  enabled: true
  image:
    repository: "<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/yas-sampledata"
    tag: latest
  service:
    type: ClusterIP
  env:
    SPRING_DATASOURCE_PRODUCT_URL: "jdbc:postgresql://infra-postgresql.infrastructure.svc.cluster.local:5432/product"
    SPRING_DATASOURCE_MEDIA_URL: "jdbc:postgresql://infra-postgresql.infrastructure.svc.cluster.local:5432/media"
    SPRING_DATASOURCE_USERNAME: "admin"
    SPRING_DATASOURCE_PASSWORD: "admin"
    SPRING_DATASOURCE_DRIVER_CLASS_NAME: "org.postgresql.Driver"
    SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI: "https://identity.yas.io/realms/Yas"
    CORS_ALLOWED_ORIGINS: "https://storefront.yas.io,https://backoffice.yas.io"

# Tắt Tailscale (không dùng trong AWS)
tailscale:
  backendIp: ""

# Bật Istio nếu cần (optional)
istio:
  enabled: false
  domain: api.yas.io
```

---

## Phase 7 – Deploy Observability Stack

### 7.1 Deploy qua ArgoCD

```bash
kubectl apply -f argocd/applications/observability.yaml
```

### 7.2 Cập nhật `argocd/applications/observability.yaml` cho AWS

```yaml
# argocd/applications/observability.yaml - AWS VERSION
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: observability
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  project: yas
  source:
    repoURL: https://github.com/<YOUR_ORG>/yas-gitops.git
    targetRevision: main
    path: helm/observability
    helm:
      valueFiles:
        - values.yaml
        - values-aws.yaml   # ← File mới cho AWS
  destination:
    server: https://kubernetes.default.svc
    namespace: observability
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 7.3 Tạo `helm/observability/values-aws.yaml`

```yaml
# helm/observability/values-aws.yaml
loki:
  enabled: true
  persistence:
    storageClass: ebs-sc  # ← Dùng EBS

promtail:
  enabled: true

tempo:
  enabled: true
  persistence:
    storageClass: ebs-sc

kube-prometheus-stack:
  enabled: true
  prometheus:
    prometheusSpec:
      storageSpec:
        volumeClaimTemplate:
          spec:
            storageClassName: ebs-sc
            resources:
              requests:
                storage: 20Gi
  grafana:
    ingress:
      enabled: true
      annotations:
        kubernetes.io/ingress.class: nginx
      hosts:
        - grafana.yas.io
      tls:
        - secretName: grafana-tls
          hosts:
            - grafana.yas.io

kiali-server:
  enabled: true
```

### 7.4 Expose Grafana & Kiali qua Ingress

Grafana sẽ được expose qua `https://grafana.yas.io`.
Kiali qua `https://kiali.yas.io`.

---

## Phase 8 – Thay Đổi Source Code & Cấu Hình

### 8.1 Cập nhật Jenkinsfile – Dùng ECR thay Docker Hub

Sửa file `yas/Jenkinsfile`, phần **Build and Push Docker Images**:

```groovy
// TRƯỚC (Docker Hub):
// def IMAGE = "${DOCKERHUB_USERNAME}/yas-${module}:${IMAGE_TAG}"
// docker login --username "${DOCKERHUB_USERNAME}" ...

// SAU (ECR):
stage('Build and Push Docker Images') {
    when {
        expression { env.AFFECTED_DOCKER_MODULES?.trim() }
    }
    steps {
        script {
            def commitId = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
            def dockerModules = getDockerModules().findAll { module ->
                fileExists("${module}/Dockerfile")
            }

            if (!dockerModules) {
                echo 'No affected module has a Dockerfile; skipping.'
                return
            }

            env.IMAGE_TAG = commitId

            withCredentials([
                [
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]
            ]) {
                def ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

                sh """
                    set -eu
                    aws ecr get-login-password --region ${AWS_REGION} | \\
                        docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    trap 'docker logout ${ECR_REGISTRY} >/dev/null 2>&1 || true' EXIT
                """

                dockerModules.each { module ->
                    sh """
                        IMAGE="${ECR_REGISTRY}/yas-${module}:${env.IMAGE_TAG}"
                        echo "Building \${IMAGE}"
                        docker build --pull --tag "\${IMAGE}" "${module}"
                        docker push "\${IMAGE}"

                        # Also tag as latest
                        docker tag "\${IMAGE}" "${ECR_REGISTRY}/yas-${module}:latest"
                        docker push "${ECR_REGISTRY}/yas-${module}:latest"
                    """
                }
            }
        }
    }
}
```

Thêm environment variables vào Jenkinsfile:

```groovy
environment {
    MVN_ARGS = '-B -ntp'
    MAVEN_MODULES = 'backoffice-bff storefront-bff cart customer inventory media order product promotion search tax sampledata'
    DOCKER_SERVICES = 'backoffice backoffice-bff storefront storefront-bff cart customer inventory media order product promotion search tax sampledata'
    SNYK_HOME = tool name: 'snyk@latest'
    REVISION = '1.0-SNAPSHOT'

    // ← THÊM CHO AWS
    AWS_ACCOUNT_ID = '123456789012'      // ← Thay bằng Account ID thực
    AWS_REGION = 'us-east-1'
    ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
}
```

### 8.2 Thêm Stage Update GitOps sau Build

Thêm stage sau **Build and Push Docker Images** để tự động update `values-aws-prod.yaml`:

```groovy
stage('Update GitOps ImageTag') {
    when {
        expression { env.AFFECTED_DOCKER_MODULES?.trim() && env.BRANCH_NAME == 'main' }
    }
    steps {
        script {
            def dockerModules = getDockerModules()
            withCredentials([usernamePassword(
                credentialsId: 'github-creds',
                passwordVariable: 'GIT_PASSWORD',
                usernameVariable: 'GIT_USERNAME'
            )]) {
                dir('yas-gitops') {
                    sh """
                        git clone https://\${GIT_USERNAME}:\${GIT_PASSWORD}@github.com/<YOUR_ORG>/yas-gitops.git .
                        git config user.email "ci@yas.io"
                        git config user.name "Jenkins CI"
                    """

                    dockerModules.each { module ->
                        sh """
                            sed -i 's|yas-${module}:.*|yas-${module}:${env.IMAGE_TAG}|g' \\
                                helm/yas/values-aws-prod.yaml
                        """
                    }

                    sh """
                        git add helm/yas/values-aws-prod.yaml
                        git commit -m "ci: update image tags for ${env.BRANCH_NAME} [build #${BUILD_NUMBER}]" || true
                        git push origin main
                    """
                }
            }
        }
    }
}
```

### 8.3 Cập nhật ConfigMap – Đổi URLs sang HTTPS

Sửa `yas-gitops/helm/yas/templates/yas-configuration-configmap.yaml`:

```yaml
# Thay các URL local thành public domain

spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://identity.yas.io/realms/Yas  # ← Public URL
      client:
        provider:
          keycloak:
            issuer-uri: https://identity.yas.io/realms/Yas

yas:
  publicUrl: https://api.yas.io/api/media  # ← HTTPS

springdoc:
  oauthflow:
    authorization-url: https://identity.yas.io/realms/Yas/protocol/openid-connect/auth
    token-url: https://identity.yas.io/realms/Yas/protocol/openid-connect/token
```

### 8.4 Cập nhật Nginx Ingress Template cho AWS

Sửa `yas-gitops/helm/yas/templates/nginx-ingress.yaml` – Đổi service type từ `NodePort` sang `ClusterIP` (traffic đến qua ALB):

```yaml
# Thay NodePort → sử dụng Kubernetes Ingress resource thay thế
# Thêm annotations cho AWS ALB:
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: yas-ingress
  namespace: {{ .Release.Namespace }}
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
spec:
  tls:
    - hosts:
        - storefront.yas.io
        - backoffice.yas.io
        - api.yas.io
        - identity.yas.io
      secretName: yas-tls-secret
  rules:
    - host: storefront.yas.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: storefront-nextjs
                port:
                  number: 3000
    - host: backoffice.yas.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: backoffice-nextjs
                port:
                  number: 3000
    - host: api.yas.io
      http:
        paths:
          - path: /storefront
            pathType: Prefix
            backend:
              service:
                name: storefront-bff
                port:
                  number: 8082
          - path: /backoffice
            pathType: Prefix
            backend:
              service:
                name: backoffice-bff
                port:
                  number: 8082
    - host: identity.yas.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: infra-keycloak
                port:
                  number: 80
```

---

## Phase 9 – Networking & Domain

### 9.1 Route 53 – Cấu hình DNS

```bash
# 1. Tạo Hosted Zone
aws route53 create-hosted-zone \
    --name yas.io \
    --caller-reference $(date +%s)

# 2. Lấy ALB DNS sau khi Nginx Ingress được cài
INGRESS_ALB=$(kubectl get svc ingress-nginx-controller \
    -n kube-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# 3. Tạo A Record ALIAS cho từng subdomain
# (Thực hiện qua Console hoặc AWS CLI)
# storefront.yas.io → ALIAS → $INGRESS_ALB
# backoffice.yas.io → ALIAS → $INGRESS_ALB
# api.yas.io        → ALIAS → $INGRESS_ALB
# identity.yas.io   → ALIAS → $INGRESS_ALB
# grafana.yas.io    → ALIAS → $INGRESS_ALB
# kiali.yas.io      → ALIAS → $INGRESS_ALB
```

### 9.2 ACM – SSL/TLS Certificate

```bash
# Request wildcard certificate
aws acm request-certificate \
    --domain-name "*.yas.io" \
    --validation-method DNS \
    --subject-alternative-names "yas.io" \
    --region us-east-1

# Validate qua DNS (thêm CNAME record vào Route 53)
# Sau khi validate → Certificate ARN

# Cấu hình ALB Ingress dùng certificate:
# Thêm annotation vào Ingress:
annotations:
  service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:us-east-1:<ACCOUNT_ID>:certificate/<CERT_ID>"
  service.beta.kubernetes.io/aws-load-balancer-backend-protocol: http
  service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
```

### 9.3 Cài cert-manager cho TLS trong Cluster

```bash
# Cài cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --set installCRDs=true

# Tạo ClusterIssuer dùng ACM (hoặc Let's Encrypt)
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@yas.io
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

---

## Phase 10 – CI/CD Pipeline Hoàn Chỉnh

### 10.1 Flow CI/CD Đầy Đủ trên AWS

```
Developer push code
        │
        ▼
   GitHub (yas repo)
        │
        │ Webhook (ngrok/domain public)
        ▼
   Jenkins (EC2)
   ┌─────────────────────────────────────────────┐
   │ 1. Checkout                                  │
   │ 2. Gitleaks Scan                             │
   │ 3. Detect Changes                            │
   │ 4. Maven Build                               │
   │ 5. Unit & Integration Tests                  │
   │ 6. Snyk Security Scan                        │
   │ 7. Coverage Gate (JaCoCo ≥70%)              │
   │ 8. SonarQube Analysis                        │
   │ 9. Build & Push Docker → ECR                 │
   │ 10. Update GitOps values (yas-gitops repo)   │
   └─────────────────────────────────────────────┘
        │
        │ Git push to yas-gitops
        ▼
   GitHub (yas-gitops repo)
        │
        │ ArgoCD polling (30s)
        ▼
   ArgoCD (EKS)
        │ Auto Sync
        ▼
   Amazon EKS
   ┌─────────────────────────────────────────────┐
   │ namespace: yas-prod                          │
   │ - Rolling update của service thay đổi        │
   │ - Health checks pass                         │
   │ - Traffic routing qua ALB + Nginx            │
   └─────────────────────────────────────────────┘
```

### 10.2 Cấu hình GitHub Webhook đến Jenkins

```bash
# Jenkins EC2 cần có public URL (dùng Elastic IP + Security Group mở 8080)
# Hoặc dùng ngrok (dev/test):
# ngrok http 8080

# Trong GitHub repo settings → Webhooks → Add webhook:
# Payload URL: http://<JENKINS_PUBLIC_IP>:8080/github-webhook/
# Content type: application/json
# Events: Push, Pull request
```

### 10.3 Cấu hình Jenkins Pipeline cho Multi-branch

Trong Jenkins → New Item → Multibranch Pipeline:
- Branch sources: GitHub với credentials `github-creds`
- Scan triggers: 1 phút
- Jenkinsfile path: `Jenkinsfile`

---

## Chi Phí Ước Tính

> **Lưu ý:** Giá tham khảo, region us-east-1, có thể thay đổi.

| Dịch vụ | Cấu hình | Chi phí/tháng |
|---|---|---|
| **EKS Control Plane** | 1 cluster | ~$73 |
| **EC2 Nodes (infra)** | 2x t3.xlarge | ~$120 |
| **EC2 Nodes (app)** | 3x t3.large Spot | ~$45 |
| **EC2 Nodes (o11y)** | 1x t3.large | ~$25 |
| **EC2 Jenkins** | 1x t3.large | ~$60 |
| **ALB** | 1 load balancer | ~$20 |
| **NAT Gateway** | 1 | ~$45 |
| **EBS Volumes** | ~200GB gp3 total | ~$20 |
| **ECR** | Storage + transfer | ~$5 |
| **Route 53** | 1 hosted zone | ~$1 |
| **ACM** | Free | $0 |
| **Data Transfer** | ~50GB/tháng | ~$5 |
| **Tổng cộng** | | **~$419/tháng** |

### Tối ưu chi phí:
- Dùng **Spot Instances** cho app nodes: tiết kiệm 60-70%
- **KReserved Instances** 1 năm cho Jenkins + infra nodes: tiết kiệm 30-40%
- Tắt cluster khi không dùng (dev/test)

---

## Checklist Tổng Hợp

### ✅ Phase 1 – AWS Foundation
- [ ] Cài AWS CLI, eksctl, kubectl, helm
- [ ] Tạo VPC (2 Public + 2 Private Subnets)
- [ ] Gán tags `kubernetes.io/role/elb` cho subnets
- [ ] Tạo IAM Roles: EKS cluster, nodegroup, jenkins, ALB controller

### ✅ Phase 2 – Jenkins
- [ ] Launch EC2 t3.large, Ubuntu 22.04
- [ ] Cài Jenkins + Java 17 + Maven + Docker
- [ ] Cài plugins: AWS Credentials, ECR, Docker Pipeline, SonarQube, Coverage, JUnit
- [ ] Tạo credentials: github-creds, aws-credentials, snyk-quan
- [ ] Cài kubectl + helm trên Jenkins EC2
- [ ] Gán IAM Role với ECR + EKS permissions
- [ ] Cấu hình GitHub Webhook
- [ ] Cấu hình Multibranch Pipeline

### ✅ Phase 3 – EKS Cluster
- [ ] Tạo `eks-cluster.yaml` với 3 nodegroups
- [ ] `eksctl create cluster -f eks-cluster.yaml`
- [ ] Cài AWS Load Balancer Controller
- [ ] Cài Nginx Ingress Controller
- [ ] Cài AWS EBS CSI Driver
- [ ] Verify: `kubectl get nodes` all Ready

### ✅ Phase 4 – ArgoCD
- [ ] `kubectl apply -f .../install.yaml` trong namespace `argocd`
- [ ] Expose ArgoCD UI
- [ ] Cập nhật `argocd/project.yaml` cho single cluster
- [ ] Cập nhật `argocd/applications/infra.yaml`
- [ ] Tạo `argocd/applications/yas-aws-appset.yaml`
- [ ] Connect GitHub repos trong ArgoCD UI
- [ ] Apply project.yaml

### ✅ Phase 5 – Infrastructure
- [ ] Thêm `storageclass.yaml` vào `helm/infra/templates/`
- [ ] Cập nhật PVC trong PostgreSQL, Kafka, Elasticsearch templates với `storageClassName: ebs-sc`
- [ ] `kubectl apply -f argocd/applications/infra.yaml`
- [ ] Chờ tất cả pods trong `infrastructure` namespace Ready
- [ ] Port-forward Keycloak và import realm

### ✅ Phase 6 – Microservices
- [ ] Tạo 15 ECR repositories (script batch)
- [ ] Build & push initial images lên ECR
- [ ] Tạo `helm/yas/values-aws-prod.yaml` (đầy đủ ECR URLs)
- [ ] Sửa service type từ `NodePort` → `ClusterIP` trong values
- [ ] Tạo Kubernetes Ingress thay thế Nginx NodePort
- [ ] Apply ArgoCD ApplicationSet cho yas

### ✅ Phase 7 – Observability
- [ ] Tạo `helm/observability/values-aws.yaml` với EBS storage
- [ ] Cập nhật `argocd/applications/observability.yaml`
- [ ] `kubectl apply -f argocd/applications/observability.yaml`
- [ ] Verify Grafana accessible và có data

### ✅ Phase 8 – Source Code Changes
- [ ] **Jenkinsfile:** Thay Docker Hub → ECR (login, build, push)
- [ ] **Jenkinsfile:** Thêm stage "Update GitOps ImageTag"
- [ ] **Jenkinsfile:** Thêm `AWS_ACCOUNT_ID`, `AWS_REGION` env vars
- [ ] **yas-configuration-configmap.yaml:** Đổi local URLs → HTTPS public domains
- [ ] **nginx-ingress.yaml:** Đổi sang Kubernetes Ingress resource
- [ ] **values-aws-prod.yaml:** Tạo file với ECR repos và service ClusterIP
- [ ] **argocd/project.yaml:** Cập nhật single cluster destinations
- [ ] **jenkins/scripts:** Cập nhật `resolve-branch-tags.sh` trỏ về ECR
- [ ] Commit & push yas-gitops lên GitHub

### ✅ Phase 9 – Networking & Domain
- [ ] Tạo Route 53 Hosted Zone cho `yas.io`
- [ ] Request ACM wildcard certificate `*.yas.io`
- [ ] Validate certificate qua DNS
- [ ] Lấy ALB DNS của Nginx Ingress Controller
- [ ] Tạo Route 53 A Records cho tất cả subdomains
- [ ] Cài cert-manager hoặc dùng ACM trực tiếp
- [ ] Verify HTTPS cho storefront.yas.io, backoffice.yas.io, api.yas.io

### ✅ Phase 10 – End-to-End Verification
- [ ] Truy cập `https://storefront.yas.io` thành công
- [ ] Truy cập `https://backoffice.yas.io` thành công
- [ ] Login Keycloak qua `https://identity.yas.io` hoạt động
- [ ] Swagger UI `https://api.yas.io/swagger` truy cập được
- [ ] Grafana `https://grafana.yas.io` có metrics từ services
- [ ] Traces visible trong Tempo
- [ ] Logs visible trong Loki
- [ ] Commit code → Jenkins build → ECR push → ArgoCD sync → Pod update tự động

---

## 🔒 Bảo Mật Bổ Sung (Recommended)

### AWS Secrets Manager thay thế hardcoded passwords

```bash
# Tạo secret
aws secretsmanager create-secret \
    --name yas/postgresql \
    --secret-string '{"username":"admin","password":"<STRONG_PASSWORD>"}'

# Dùng External Secrets Operator trong K8s để sync vào Kubernetes Secrets
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
    --namespace external-secrets --create-namespace
```

### IRSA cho Pods cần AWS permissions

```bash
# Ví dụ cho media service cần S3 access:
eksctl create iamserviceaccount \
    --cluster=yas-cluster \
    --namespace=yas-prod \
    --name=media-sa \
    --attach-policy-arn=arn:aws:iam::aws:policy/AmazonS3FullAccess \
    --approve
```

---

> **📝 Tóm tắt thay đổi chính:**
> 1. **Tailscale VPN** → **AWS VPC** (không cần multi-cluster nữa)
> 2. **NodePort** → **ClusterIP + Kubernetes Ingress + ALB**
> 3. **Docker Hub** → **Amazon ECR**
> 4. **/etc/hosts** → **Route 53**
> 5. **Local paths** → **HTTPS public domains** trong tất cả configs
> 6. **Manual Keycloak import** → Giữ nguyên (một lần duy nhất)
> 7. **EBS CSI Driver** thay thế local disk cho PersistentVolumes
