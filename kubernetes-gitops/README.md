# Kubernetes GitOps Homework

This homework demonstrates GitOps practices using ArgoCD to deploy and manage Kubernetes applications.

## Prerequisites

- Yandex Cloud Managed Kubernetes cluster (from previous homeworks)
- kubectl configured to access the cluster
- Helm installed
- Infra nodes configured with `node-role=infra:NoSchedule` taint and label

## Repository Structure

```
RurikV_repo/ (or your fork: otus-k8s-samoair)
├── kubernetes-networks/       ← Application source code (kubernetes-networks homework)
├── kubernetes-templating/     ← Application source code (kubernetes-templating homework)
│   └── helm-chart/            ← Helm chart for kubernetes-templating
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
│  - Source: ../kubernetes-templating/helm-chart/              │
│  - Namespace: HomeworkHelm                                  │
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

### 1.4 Access ArgoCD UI

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d && echo

# Port-forward to access ArgoCD UI
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Open browser: https://localhost:8080
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
- Source Repositories: Your homework repository (`https://github.com/RurikV/otus-k8s-samoair.git`)
- Destinations: Current cluster (selected namespaces only)
- Cluster Resource Whitelist: Limited to specific namespaces
- Namespace Resource Whitelist: Limited to homework namespaces
- Sync Windows: No restrictions

## Step 3: Deploy kubernetes-networks Application (Manual Sync)

This application deploys the kubernetes-networks homework from the sibling directory.

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
- Application pods use `nodeSelector: node-role=worker`
- This ensures deployment on worker nodes (not infra)
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
- **Namespace:** `HomeworkHelm`
- **Source:** `kubernetes-templating/helm-chart/` directory (sibling to this directory)
- **Helm Override:** `replicas: 2` (demonstrates value customization)

**Key Features:**
- Automatic synchronization from Git repository
- Self-healing: detects and fixes configuration drift
- Pruning: removes resources deleted from Git
- Separate namespace demonstrates multi-application management

## Verification

### Check ArgoCD Components on Infra Nodes

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
# NAME                      PROJECT  SYNC STATUS  HEALTH
# kubernetes-networks       otus     OutOfSync   Missing
# kubernetes-templating    otus     Synced      Healthy
```

### Verify Namespace Separation

```bash
kubectl get ns
# homework       - for kubernetes-networks
# HomeworkHelm   - for kubernetes-templating
```

### Verify Source Directory References

```bash
# From kubernetes-gitops directory, verify sibling directories exist
ls -la ../kubernetes-networks
ls -la ../kubernetes-templating/helm-chart
```

## Troubleshooting

### ArgoCD Server Not Starting

```bash
# Check if infra node is available
kubectl get node -l node-role=infra

# Check ArgoCD pod logs
kubectl logs -n argocd -l app.kubernetes.io/name=argo-cd
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
git ls-remote --heads git@github.com:RurikV/otus-k8s-samoair.git

# Or check locally
ls -la ../kubernetes-networks
ls -la ../kubernetes-templating/helm-chart
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
kubectl delete namespace homework HomeworkHelm
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
├── manifests/
└── ...

../kubernetes-templating/        (Sibling directory - application source code)
└── helm-chart/
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
  - [ ] Pods in separate namespaces (homework, HomeworkHelm)
  - [ ] Application source showing correct directory paths
