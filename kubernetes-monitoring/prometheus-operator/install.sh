#!/bin/bash

# Install Prometheus Operator using Helm
# This script installs the kube-prometheus-stack which includes:
# - Prometheus Operator
# - Prometheus server
# - Alertmanager
# - Grafana
# - Node Exporter
# - kube-state-metrics

set -e

echo "=== Installing Prometheus Operator ==="

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "Error: helm is not installed. Please install helm first."
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Add Prometheus Community Helm repository
echo "Adding Prometheus Community Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace
echo "Creating monitoring namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Install Prometheus Operator
echo "Installing Prometheus Operator (this may take a few minutes)..."
helm upgrade --install prometheus-operator prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set grafana.service.type=ClusterIP \
  --set prometheus.service.type=ClusterIP \
  --set alertmanager.service.type=ClusterIP

# Wait for pods to be ready
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=prometheus-operator -n monitoring --timeout=300s

# Show status
echo ""
echo "=== Installation Complete ==="
echo ""
echo "Pods in monitoring namespace:"
kubectl get pods -n monitoring
echo ""
echo "To access Prometheus UI:"
echo "  kubectl port-forward svc/prometheus-operated -n monitoring 9090:9090"
echo "  Then open: http://localhost:9090"
echo ""
echo "To access Grafana:"
echo "  kubectl port-forward svc/prometheus-operator-grafana -n monitoring 3000:80"
echo "  Then open: http://localhost:3000"
echo "  Default credentials: admin / prom-operator"
echo ""
echo "Next steps:"
echo "  1. Deploy nginx with exporter: kubectl apply -f ../nginx-deployment/"
echo "  2. Verify metrics are being collected in Prometheus UI"