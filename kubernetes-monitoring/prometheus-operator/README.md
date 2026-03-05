# Prometheus Operator Installation

This directory contains instructions and scripts for installing Prometheus Operator in your Kubernetes cluster.

## Installation Methods

### Method 1: Using Helm (Recommended)

The easiest and most popular way to install Prometheus Operator is using the kube-prometheus-stack Helm chart.

```bash
# Add the Prometheus Community Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring

# Install Prometheus Operator
helm install prometheus-operator prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false
```

### Method 2: Using kubectl with kube-prometheus manifests

```bash
# Clone the kube-prometheus repository
git clone https://github.com/prometheus-operator/kube-prometheus.git
cd kube-prometheus

# Create the monitoring namespace and CRDs
kubectl create -f manifests/setup

# Wait for CRDs to be ready
sleep 10

# Deploy the complete stack
kubectl create -f manifests/
```

## Verify Installation

After installation, verify that all components are running:

```bash
# Check pods in monitoring namespace
kubectl get pods -n monitoring

# Expected output:
# NAME                                                     READY   STATUS    RESTARTS   AGE
# alertmanager-prometheus-operator-kube-p-alertmanager-0   2/2     Running   0          1m
# prometheus-operator-grafana-xxx-yyy                       3/3     Running   0          1m
# prometheus-operator-kube-p-state-metrics-xxx-yyy         1/1     Running   0          1m
# prometheus-operator-prometheus-node-exporter-xxx         1/1     Running   0          1m
# prometheus-prometheus-operator-kube-p-prometheus-0        2/2     Running   0          1m

# Check ServiceMonitors
kubectl get servicemonitors -n monitoring

# Check Prometheus instance
kubectl get prometheus -n monitoring
```

## Access Prometheus UI

To access the Prometheus web UI:

```bash
# Port-forward to Prometheus service
kubectl port-forward svc/prometheus-operated -n monitoring 9090:9090

# Open in browser: http://localhost:9090
```

## Access Grafana

To access Grafana dashboard:

```bash
# Port-forward to Grafana service
kubectl port-forward svc/prometheus-operator-grafana -n monitoring 3000:80

# Open in browser: http://localhost:3000
# Get credentials (username: admin):
kubectl get secret prometheus-operator-grafana -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d && echo
```

## Uninstall

### Uninstall Helm installation

```bash
helm uninstall prometheus-operator -n monitoring
kubectl delete namespace monitoring
```

### Uninstall manifest-based installation

```bash
cd kube-prometheus
kubectl delete --ignore-not-found=true -f manifests/
kubectl delete --ignore-not-found=true -f manifests/setup
```

## Important Notes

1. **ServiceMonitor Labels**: The ServiceMonitor must have a label that matches the Prometheus operator's `serviceMonitorSelector`. By default, when using Helm, the label is `release: <helm-release-name>`.

2. **Namespace**: All monitoring resources should be deployed in the `monitoring` namespace.

3. **Resource Requirements**: Prometheus Operator stack requires significant resources. Ensure your cluster has enough resources (at least 4GB RAM, 2 CPUs available).

4. **Storage**: By default, Prometheus uses emptyDir. For production, configure persistent storage using the Helm values.

## Next Steps

After installing Prometheus Operator, deploy the nginx application using the manifests in `../nginx-deployment/` directory.