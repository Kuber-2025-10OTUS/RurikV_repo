# Kubernetes Logging Homework

This homework deploys a centralized logging solution using Loki, Promtail, and Grafana on Yandex Cloud Managed Kubernetes.

## Architecture

- **Loki**: Log aggregation system (monolithic mode, stored in S3)
- **Promtail**: Log collection agent (DaemonSet on all nodes)
- **Grafana**: Visualization UI with Loki datasource pre-configured
- **S3 Bucket**: Yandex Cloud Object Storage for log persistence

## Prerequisites

- Yandex Cloud account with access to Managed Kubernetes
- YC CLI installed
- Terraform installed
- kubectl installed
- helm installed

## Step 1: Deploy Infrastructure with Terraform

### 1.1 Configure Terraform variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values or use environment variables
```

### 1.2 Set environment variables (alternative to tfvars)

```bash
export YC_CLOUD_ID="your-cloud-id"
export YC_FOLDER_ID="your-folder-id"
export YC_ZONE="ru-central1-a"
export YC_TOKEN="your-oauth-token"  # Or authenticate via yc init
```

### 1.3 Initialize and apply Terraform

```bash
terraform init
terraform plan
terraform apply
```

### 1.4 Get kubeconfig

```bash
# Output from terraform apply shows the command
yc managed-kubernetes cluster get-credentials logging-cluster --external
```

## Step 2: Verify Node Configuration

For homework submission, run these commands:

```bash
# Show all nodes with labels
kubectl get node -o wide --show-labels

# Show taints configuration
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

Expected output:
- Worker nodes: no taints, label `node-role=worker`
- Infra nodes: taint `node-role=infra:NoSchedule`, label `node-role=infra`

## Step 3: Install Helm Charts

### 3.1 Add Helm repositories

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

### 3.2 Create monitoring namespace

```bash
kubectl create namespace monitoring
```

### 3.3 Install Loki

```bash
helm upgrade --install loki grafana/loki \
  -n monitoring \
  -f ../helm-charts/values-loki.yaml
```

**Note**: Update `values-loki.yaml` with your S3 credentials:
- Replace `${S3_ACCESS_KEY}` with actual access key from terraform output
- Replace `${S3_SECRET_KEY}` with actual secret key from terraform output

Get S3 credentials:
```bash
terraform output -raw s3_access_key
terraform output -raw s3_secret_key
```

### 3.4 Install Promtail

```bash
helm upgrade --install promtail grafana/promtail \
  -n monitoring \
  -f ../helm-charts/values-promtail.yaml
```

### 3.5 Install Grafana

```bash
helm upgrade --install grafana grafana/grafana \
  -n monitoring \
  -f ../helm-charts/values-grafana.yaml
```

## Step 4: Verify Installation

### 4.1 Check pods are running

```bash
kubectl get pods -n monitoring
```

Expected:
- `loki-*` pods on infra nodes only
- `promtail-*` pods on all nodes (worker + infra)
- `grafana-*` pod on infra node only

### 4.2 Get Grafana credentials

```bash
# Default admin credentials
Username: admin
Password: admin123
```

### 4.3 Access Grafana

```bash
# Port-forward to access Grafana locally
kubectl port-forward -n monitoring svc/grafana 3000:80
```

Then open: http://localhost:3000

Or use LoadBalancer IP:
```bash
kubectl get svc -n monitoring grafana
```

### 4.4 Explore Logs in Grafana

1. Open Grafana
2. Navigate to **Explore** (left sidebar)
3. Select **Loki** datasource
4. Run query: `{job="promtail/"}`
5. Verify logs are displayed

Take a screenshot of the Grafana Explore page showing logs for homework submission.

## Homework Submission Checklist

- [ ] Node configuration screenshot/output (`kubectl get node -o wide --show-labels`)
- [ ] Taints configuration output (`kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints`)
- [ ] S3 bucket name from terraform output
- [ ] Loki values file (`helm-charts/values-loki.yaml`)
- [ ] Promtail values file (`helm-charts/values-promtail.yaml`)
- [ ] Grafana values file (`helm-charts/values-grafana.yaml`)
- [ ] Helm installation commands used
- [ ] Screenshot of Grafana showing logs from Loki datasource

## Architecture Diagram

```
┌─────────────────┐     ┌──────────────────┐
│   Worker Node   │     │   Infra Node     │
│  (no taints)    │     │  node-role=infra │
│                 │     │  NoSchedule      │
├─────────────────┤     ├──────────────────┤
│                 │     │                  │
│  [Applications] │     │     Loki ✓       │
│                 │     │     Grafana ✓    │
│  [Promtail ✓]   │────▶│                  │
└─────────────────┘     │  [Promtail ✓]    │
                        └────────┬─────────┘
                                 │
                                 ▼
                        ┌─────────────────┐
                        │  YC S3 Bucket   │
                        │  (Loki logs)    │
                        └─────────────────┘
```

## Troubleshooting

### Pods not scheduling on infra nodes

Check node selector and tolerations match:
```bash
kubectl describe node <infra-node-name>
kubectl get pod -n monitoring -o wide
```

### Loki cannot connect to S3

Verify S3 credentials in values-loki.yaml match terraform outputs.

### Grafana not showing logs

1. Check Loki is running: `kubectl logs -n monitoring -l app=loki`
2. Check Promtail is shipping logs: `kubectl logs -n monitoring -l app=promtail`
3. Verify datasource configuration in Grafana

## Cleanup

```bash
# Delete Helm releases
helm uninstall -n monitoring loki promtail grafana

# Delete Kubernetes cluster
cd terraform
terraform destroy
```