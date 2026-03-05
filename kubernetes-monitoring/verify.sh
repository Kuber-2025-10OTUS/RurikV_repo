#!/bin/bash

# Verification script for Kubernetes monitoring setup
# This script checks if all components are properly deployed and working

set -e

NAMESPACE="monitoring"
APP_NAME="nginx-with-exporter"

echo "=== Kubernetes Monitoring Verification Script ==="
echo ""

# Function to check if a command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo "❌ $1 is not installed. Please install it first."
        exit 1
    fi
}

# Check prerequisites
echo "1. Checking prerequisites..."
check_command kubectl
echo "✅ kubectl is installed"

if kubectl cluster-info &> /dev/null; then
    echo "✅ Kubernetes cluster is accessible"
else
    echo "❌ Cannot connect to Kubernetes cluster"
    exit 1
fi

# Check monitoring namespace
echo ""
echo "2. Checking monitoring namespace..."
if kubectl get namespace $NAMESPACE &> /dev/null; then
    echo "✅ Namespace '$NAMESPACE' exists"
else
    echo "❌ Namespace '$NAMESPACE' not found"
    echo "   Run: kubectl create namespace $NAMESPACE"
    exit 1
fi

# Check Prometheus Operator pods
echo ""
echo "3. Checking Prometheus Operator components..."
PROMETHEUS_PODS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
if [ -n "$PROMETHEUS_PODS" ]; then
    echo "✅ Prometheus pods are running:"
    echo "   $PROMETHEUS_PODS"
else
    echo "⚠️  No Prometheus pods found. Did you install Prometheus Operator?"
    echo "   Run: cd prometheus-operator && ./install.sh"
fi

# Check nginx deployment
echo ""
echo "4. Checking nginx-with-exporter deployment..."
NGINX_DEPLOYMENT=$(kubectl get deployment $APP_NAME -n $NAMESPACE -o jsonpath='{.metadata.name}' 2>/dev/null || true)
if [ -n "$NGINX_DEPLOYMENT" ]; then
    echo "✅ Deployment '$APP_NAME' exists"

    READY_REPLICAS=$(kubectl get deployment $APP_NAME -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    DESIRED_REPLICAS=$(kubectl get deployment $APP_NAME -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")

    if [ "$READY_REPLICAS" == "$DESIRED_REPLICAS" ] && [ "$READY_REPLICAS" != "0" ]; then
        echo "✅ All $READY_REPLICAS replica(s) are ready"
    else
        echo "⚠️  Only $READY_REPLICAS/$DESIRED_REPLICAS replicas are ready"
    fi
else
    echo "❌ Deployment '$APP_NAME' not found"
    echo "   Run: kubectl apply -f nginx-deployment/"
    exit 1
fi

# Check nginx pods
echo ""
echo "5. Checking nginx pods..."
NGINX_PODS=$(kubectl get pods -n $NAMESPACE -l app=$APP_NAME -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
if [ -n "$NGINX_PODS" ]; then
    echo "✅ Found nginx pods:"
    for POD in $NGINX_PODS; do
        echo "   - $POD"
    done
else
    echo "❌ No nginx pods found"
    exit 1
fi

# Check Service
echo ""
echo "6. Checking Service..."
SERVICE=$(kubectl get svc $APP_NAME -n $NAMESPACE -o jsonpath='{.metadata.name}' 2>/dev/null || true)
if [ -n "$SERVICE" ]; then
    echo "✅ Service '$APP_NAME' exists"
    METRICS_PORT=$(kubectl get svc $APP_NAME -n $NAMESPACE -o jsonpath='{.spec.ports[?(@.name=="metrics")].port}' 2>/dev/null || true)
    if [ -n "$METRICS_PORT" ]; then
        echo "✅ Metrics port configured: $METRICS_PORT"
    else
        echo "⚠️  Metrics port not found in service"
    fi
else
    echo "❌ Service '$APP_NAME' not found"
fi

# Check ServiceMonitor
echo ""
echo "7. Checking ServiceMonitor..."
SERVICEMONITOR=$(kubectl get servicemonitor $APP_NAME -n $NAMESPACE -o jsonpath='{.metadata.name}' 2>/dev/null || true)
if [ -n "$SERVICEMONITOR" ]; then
    echo "✅ ServiceMonitor '$APP_NAME' exists"

    # Check if ServiceMonitor has the correct label
    SM_LABEL=$(kubectl get servicemonitor $APP_NAME -n $NAMESPACE -o jsonpath='{.metadata.labels.release}' 2>/dev/null || true)
    if [ -n "$SM_LABEL" ]; then
        echo "✅ ServiceMonitor has release label: $SM_LABEL"
    else
        echo "⚠️  ServiceMonitor missing 'release' label"
    fi
else
    echo "❌ ServiceMonitor '$APP_NAME' not found"
    echo "   Run: kubectl apply -f nginx-deployment/servicemonitor.yaml"
fi

# Check ConfigMap
echo ""
echo "8. Checking ConfigMap..."
CONFIGMAP=$(kubectl get configmap nginx-config -n $NAMESPACE -o jsonpath='{.metadata.name}' 2>/dev/null || true)
if [ -n "$CONFIGMAP" ]; then
    echo "✅ ConfigMap 'nginx-config' exists"
else
    echo "❌ ConfigMap 'nginx-config' not found"
fi

# Test nginx status endpoint
echo ""
echo "9. Testing nginx stub_status endpoint..."
FIRST_POD=$(kubectl get pods -n $NAMESPACE -l app=$APP_NAME -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "$FIRST_POD" ]; then
    echo "Testing pod: $FIRST_POD"

    STATUS=$(kubectl exec -n $NAMESPACE $FIRST_POD -c nginx -- wget -qO- http://localhost:80/nginx_status 2>/dev/null || true)
    if [ -n "$STATUS" ]; then
        echo "✅ stub_status endpoint is accessible"
        echo "   Response:"
        echo "$STATUS" | sed 's/^/   /'
    else
        echo "❌ Cannot access stub_status endpoint"
    fi
else
    echo "⚠️  No pods found to test"
fi

# Test nginx exporter metrics endpoint
echo ""
echo "10. Testing nginx-prometheus-exporter metrics endpoint..."
if [ -n "$FIRST_POD" ]; then
    METRICS=$(kubectl exec -n $NAMESPACE $FIRST_POD -c nginx-exporter -- wget -qO- http://localhost:9113/metrics 2>/dev/null | grep -E "^nginx_" || true)
    if [ -n "$METRICS" ]; then
        echo "✅ Metrics endpoint is accessible"
        echo "   Sample metrics:"
        echo "$METRICS" | head -n 5 | sed 's/^/   /'
    else
        echo "❌ Cannot access metrics endpoint"
    fi
else
    echo "⚠️  No pods found to test"
fi

# Summary
echo ""
echo "=== Verification Summary ==="
echo ""
echo "To access Prometheus UI:"
echo "  kubectl port-forward svc/prometheus-operated -n $NAMESPACE 9090:9090"
echo "  Open: http://localhost:9090"
echo ""
echo "To access Grafana:"
echo "  kubectl port-forward svc/prometheus-operator-grafana -n $NAMESPACE 3000:80"
echo "  Open: http://localhost:3000"
echo "  Default credentials: admin / prom-operator"
echo ""
echo "To test metrics collection in Prometheus:"
echo "  1. Open Prometheus UI (http://localhost:9090)"
echo "  2. Go to Status -> Targets"
echo "  3. Look for 'monitoring/nginx-with-exporter' target"
echo "  4. Try queries:"
echo "     - nginx_up"
echo "     - nginx_http_requests_total"
echo "     - nginx_connections_active"
echo "     - rate(nginx_http_requests_total[5m])"
echo ""
echo "To generate load on nginx:"
echo "  kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c 'while sleep 0.01; do wget -q -O- http://nginx-with-exporter.monitoring.svc.cluster.local/ > /dev/null; done'"
echo ""
echo "Verification complete!"