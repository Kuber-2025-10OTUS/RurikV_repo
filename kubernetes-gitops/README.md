# Kubernetes GitOps Homework

This homework demonstrates GitOps practices using ArgoCD to deploy and manage Kubernetes applications.

## Prerequisites

- Yandex Cloud Managed Kubernetes cluster (from previous homeworks)
- kubectl configured to access the cluster
- Helm installed
- ArgoCD CLI installed
- Infra nodes configured with `node-role=infra:NoSchedule` taint and label
- Worker node labeled with `homework=true` (for kubernetes-networks pods)

### Install ArgoCD CLI

**macOS (Homebrew):**
```bash
brew install argocd
```

**Linux (binary download):**
```bash
# Download latest version
VERSION=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | grep 'tag_name' | awk -F '"' '{print $2}')
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/argocd
```

**Verify installation:**
```bash
argocd version --short
```

## Repository Structure

```
RurikV_repo/ (or your fork: RurikV_repo)
├── kubernetes-networks/       ← Application source code (kubernetes-networks homework)
├── kubernetes-templating/     ← Application source code (kubernetes-templating homework)
│   └── web-server/            ← Helm chart for kubernetes-templating
└── kubernetes-gitops/         ← This directory (ArgoCD configuration only)
    ├── README.md
    ├── argocd-values.yaml
    ├── argocd-project-otus.yaml
    ├── app-kubernetes-networks.yaml
    └── app-kubernetes-templating.yaml
```

**Important:** The `kubernetes-gitops/` directory contains only ArgoCD manifests that reference the sibling application directories (`../kubernetes-networks` and `../kubernetes-templating`).

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     ArgoCD (Infra Nodes Only)               │
│  - ArgoCD API Server, Repo Server, Application Controller   │
│  - Redis, Notification Controller, SSO                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ Syncs
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       Project: Otus                         │
├─────────────────────────────────────────────────────────────┤
│  Application 1: kubernetes-networks (manual sync)           │
│  - Source: ../kubernetes-networks/                          │
│  - Namespace: homework                                      │
│  - Dest: Cluster                                            │
├─────────────────────────────────────────────────────────────┤
│  Application 2: kubernetes-templating (auto sync)            │
│  - Source: ../kubernetes-templating/web-server/              │
│  - Namespace: homeworkhelm                                  │
│  - Helm override: replicas=2                                │
└─────────────────────────────────────────────────────────────┘
```

## Step 1: Install ArgoCD on Infra Nodes

### 1.1 Add ArgoCD Helm Repository

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

### 1.2 Create Namespace

```bash
kubectl create namespace argocd
```

### 1.3 Install ArgoCD with Infra Node Configuration

```bash
helm upgrade --install argocd argo/argo-cd \
  -n argocd \
  -f argocd-values.yaml
```

**Key Configuration Points:**
- All ArgoCD components use `nodeSelector: node-role: infra`
- All components tolerate `node-role=infra:NoSchedule` taint
- This ensures ArgoCD control plane runs only on infra nodes
- Worker nodes remain free for application workloads

### 1.4 Configure ArgoCD CLI Access

The ArgoCD CLI needs to connect to the ArgoCD server. With `server.insecure: true`, use HTTP mode:

**Method 1: Port-forward (recommended for local access)**
```bash
# In one terminal, start port-forward (HTTP port)
kubectl port-forward -n argocd svc/argocd-server 8080:80

# In another terminal, login to ArgoCD
argocd login localhost:8080 --username admin --password \
  $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d) \
  --plaintext

# Or set environment variable for persistent connection
export ARGOCD_OPTS="--server localhost:8080 --plaintext"
```

**Method 2: LoadBalancer (if external access needed)**
```bash
# Get LoadBalancer IP
EXTERNAL_IP=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
argocd login "$EXTERNAL_IP:80" --username admin --password \
  $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d) \
  --plaintext
```

**Verify connection:**
```bash
argocd cluster list
```

### 1.5 Access ArgoCD UI

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d && echo

# Port-forward to access ArgoCD UI (if not already running)
kubectl port-forward -n argocd svc/argocd-server 8080:80

# Open browser: http://localhost:8080
# Username: admin
# Password: <use password from command above>
```

## Step 2: Create ArgoCD Project "Otus"

The project defines boundaries and policies for grouped applications.

**Apply Project Manifest:**
```bash
kubectl apply -f argocd-project-otus.yaml
```

**Project Configuration:**
- Name: `otus`
- Source Repositories: `https://github.com/samoair/RurikV_repo.git`
- Destinations: Current cluster (all namespaces)
- Cluster Resource Whitelist: Namespace, RBAC, CRDs
- Namespace Resource Whitelist: All resources allowed
- Sync Windows: No restrictions

## Step 3: Deploy kubernetes-networks Application (Manual Sync)

This application deploys the kubernetes-networks homework from the sibling directory.

**Prerequisites:**
```bash
# Label worker node for homework deployment (required by kubernetes-networks pods)
kubectl label node <worker-node-name> homework=true
```

**Apply Application Manifest:**
```bash
kubectl apply -f app-kubernetes-networks.yaml
```

**Application Details:**
- **Name:** `kubernetes-networks`
- **Project:** `otus`
- **Sync Policy:** Manual (requires manual sync trigger)
- **Namespace:** `homework`
- **Source:** `kubernetes-networks/` directory (sibling to this directory)
- **Destination:** Current cluster, namespace `homework`

**Sync Manually:**
```bash
# Via CLI
argocd app sync kubernetes-networks

# Via UI: Click "Sync" button on application page
```

**Node Placement:**
- Application pods use `nodeAffinity` requiring `homework=true` label
- This ensures deployment on labeled worker nodes (not infra)
- Demonstrates workload segregation

## Step 4: Deploy kubernetes-templating Application (Auto Sync)

This application deploys the kubernetes-templating homework with auto-sync and Helm overrides.

**Apply Application Manifest:**
```bash
kubectl apply -f app-kubernetes-templating.yaml
```

**Application Details:**
- **Name:** `kubernetes-templating`
- **Project:** `otus`
- **Sync Policy:** Auto (continuous sync from Git)
- **Auto-Prune:** `true` (removes resources when deleted from Git)
- **Self-Heal:** `true` (corrects drift)
- **Namespace:** `homeworkhelm`
- **Source:** `kubernetes-templating/web-server/` directory (sibling to this directory)
- **Helm Override:** `replicaCount: 2` (demonstrates value customization)

**Key Features:**
- Automatic synchronization from Git repository
- Self-healing: detects and fixes configuration drift
- Pruning: removes resources deleted from Git
- Separate namespace demonstrates multi-application management
- Helm value override demonstrates customization at deploy time

## Verification

### Check ArgoCD Components

```bash
kubectl get pods -n argocd -o wide

# Expected: All pods scheduled on infra node
# Example: cl1mcklbu2ottsj0h7pt-ebor (node-role=infra)
```

### Check Project

```bash
argocd proj get otus
```

### Check Applications

```bash
argocd app list

# Expected output:
# NAME                      PROJECT  SYNC STATUS  HEALTH       SYNCPOLICY
# kubernetes-networks       otus     Synced       Healthy      Manual
# kubernetes-templating    otus     Synced       Healthy      Auto-Prune
```

### Verify Namespace Separation

```bash
kubectl get ns
# homework       - for kubernetes-networks
# homeworkhelm   - for kubernetes-templating
```

### Verify Running Pods

```bash
kubectl get pods -n homework
# 3 replicas (from kubernetes-networks deployment)

kubectl get pods -n homeworkhelm
# 2 replicas (Helm override from kubernetes-templating)
```

### Verify Source Directory References

```bash
# From kubernetes-gitops directory, verify sibling directories exist
ls -la ../kubernetes-networks
ls -la ../kubernetes-templating/web-server
```

## Troubleshooting

### ArgoCD CLI Not Found

```bash
# Install argocd CLI
# macOS:
brew install argocd

# Linux:
VERSION=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | grep 'tag_name' | awk -F '"' '{print $2}')
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/argocd
```

### ArgoCD CLI Cannot Connect to Server

```bash
# Ensure port-forward is running (HTTP mode)
kubectl port-forward -n argocd svc/argocd-server 8080:80

# Login with --plaintext flag (server runs in insecure mode)
argocd login localhost:8080 --username admin --password \
  $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d) \
  --plaintext

# Or set environment variable
export ARGOCD_OPTS="--server localhost:8080 --plaintext"
argocd cluster list
```

### ArgoCD Server Not Starting

```bash
# Check if infra node is available
kubectl get node -l node-role=infra

# Check ArgoCD pod logs
kubectl logs -n argocd -l app.kubernetes.io/part-of=argocd
```

### kubernetes-networks Pods Pending

```bash
# Check pod events for scheduling issues
kubectl describe pod -n homework <pod-name>

# Ensure worker node has homework=true label
kubectl get nodes --show-labels | grep homework

# If missing, add the label:
kubectl label node <worker-node-name> homework=true
```

### Application Not Syncing

```bash
# Check application status
argocd app get <app-name>

# Sync with debug output
argocd app sync <app-name> --debug

# Check application events
argocd app get <app-name> --show-events
```

### Application Shows "Failed to sync" due to repository path

```bash
# Verify the path exists in your repository
ls -la ../kubernetes-networks
ls -la ../kubernetes-templating/web-server

# Check application configuration
argocd app get <app-name>
```

### Project Access Denied

Verify project configuration allows destination cluster and namespace:
```bash
argocd proj get otus
```

## Cleanup

```bash
# Delete applications
argocd app delete kubernetes-networks
argocd app delete kubernetes-templating

# Delete project
kubectl delete -f argocd-project-otus.yaml

# Uninstall ArgoCD
helm uninstall argocd -n argocd
kubectl delete namespace argocd

# Delete application namespaces
kubectl delete namespace homework homeworkhelm

# Remove homework label from nodes (optional)
kubectl label nodes <node-name> homework-
```

## Files Structure

```
kubernetes-gitops/              (This directory - ArgoCD manifests only)
├── README.md                    # This file
├── argocd-values.yaml           # Helm values for ArgoCD (infra node placement)
├── argocd-project-otus.yaml     # ArgoCD project manifest
├── app-kubernetes-networks.yaml  # Application manifest for ../kubernetes-networks
└── app-kubernetes-templating.yaml # Application manifest for ../kubernetes-templating

../kubernetes-networks/          (Sibling directory - application source code)
├── deployment.yaml
├── service.yaml
├── ingress.yaml
└── namespace.yaml

../kubernetes-templating/        (Sibling directory - application source code)
└── web-server/
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
```

## Homework Submission Checklist

- [ ] argocd-values.yaml with infra node configuration
- [ ] ArgoCD installation command
- [ ] argocd-project-otus.yaml manifest
- [ ] app-kubernetes-networks.yaml manifest (manual sync)
- [ ] app-kubernetes-templating.yaml manifest (auto sync, Helm override)
- [ ] Screenshots:
  - [ ] ArgoCD UI showing components on infra node
  - [ ] Project "otus" details
  - [ ] kubernetes-networks application (manual sync)
  - [ ] kubernetes-templating application (auto-synced)
  - [ ] Pods in separate namespaces (homework, homeworkhelm)
  - [ ] Application source showing correct directory paths
  - [ ] kubernetes-templating showing 2 replicas (Helm override working)
