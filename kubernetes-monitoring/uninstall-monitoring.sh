#!/bin/bash

# Uninstall script for Kubernetes monitoring setup
# This script removes all deployed resources

set -e

echo "=== Kubernetes Monitoring Uninstall Script ==="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed"
    exit 1
fi

# Check if connected to cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

NAMESPACE="monitoring"

# Confirm uninstall
echo "This script will remove:"
echo "  - nginx-with-exporter deployment and all associated resources"
echo "  - Prometheus Operator (if installed via Helm)"
echo "  - monitoring namespace (if empty after cleanup)"
echo ""
read -p "Are you sure you want to continue? (yes/no) " -r
echo
if [[ ! $REPLY == "yes" ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

echo ""
echo "=== Step 1: Remove Nginx Deployment ==="
echo "Removing nginx-with-exporter resources..."

# Delete ServiceMonitor
if kubectl get servicemonitor nginx-with-exporter -n $NAMESPACE &> /dev/null; then
    kubectl delete servicemonitor nginx-with-exporter -n $NAMESPACE
    print_success "ServiceMonitor deleted"
else
    print_warning "ServiceMonitor not found"
fi

# Delete Service
if kubectl get svc nginx-with-exporter -n $NAMESPACE &> /dev/null; then
    kubectl delete svc nginx-with-exporter -n $NAMESPACE
    print_success "Service deleted"
else
    print_warning "Service not found"
fi

# Delete Deployment
if kubectl get deployment nginx-with-exporter -n $NAMESPACE &> /dev/null; then
    kubectl delete deployment nginx-with-exporter -n $NAMESPACE
    print_success "Deployment deleted"
else
    print_warning "Deployment not found"
fi

# Delete ConfigMap
if kubectl get configmap nginx-config -n $NAMESPACE &> /dev/null; then
    kubectl delete configmap nginx-config -n $NAMESPACE
    print_success "ConfigMap deleted"
else
    print_warning "ConfigMap not found"
fi

# Delete any remaining pods
echo "Waiting for pods to terminate..."
kubectl wait --for=delete pod -l app=nginx-with-exporter -n $NAMESPACE --timeout=60s 2>/dev/null || true
print_success "All nginx pods terminated"

echo ""
echo "=== Step 2: Remove Prometheus Operator ==="
read -p "Do you want to uninstall Prometheus Operator? (yes/no) " -r
echo
if [[ $REPLY == "yes" ]]; then
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        print_error "helm is not installed, cannot uninstall via Helm"
        echo "You may need to manually remove Prometheus Operator if installed via manifests"
    else
        # Check if Prometheus Operator is installed via Helm
        if helm status prometheus-operator -n $NAMESPACE &> /dev/null; then
            echo "Uninstalling Prometheus Operator via Helm..."
            helm uninstall prometheus-operator -n $NAMESPACE
            print_success "Prometheus Operator uninstalled"

            # Wait for resources to be deleted
            echo "Waiting for Prometheus resources to be cleaned up..."
            sleep 5

            # Force delete any stuck resources
            echo "Force deleting any remaining resources..."
            kubectl delete all -l app.kubernetes.io/instance=prometheus-operator -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
            kubectl delete all -l release=prometheus-operator -n $NAMESPACE --force --grace-period=0 2>/dev/null || true

            # Delete CRDs that might be stuck
            kubectl delete crd alertmanagerconfigs.monitoring.coreos.com --ignore-not-found=true
            kubectl delete crd alertmanagers.monitoring.coreos.com --ignore-not-found=true
            kubectl delete crd podmonitors.monitoring.coreos.com --ignore-not-found=true
            kubectl delete crd probes.monitoring.coreos.com --ignore-not-found=true
            kubectl delete crd prometheuses.monitoring.coreos.com --ignore-not-found=true
            kubectl delete crd prometheusrules.monitoring.coreos.com --ignore-not-found=true
            kubectl delete crd servicemonitors.monitoring.coreos.com --ignore-not-found=true
            kubectl delete crd thanosrulers.monitoring.coreos.com --ignore-not-found=true

            print_success "Cleanup complete"
        else
            print_warning "Prometheus Operator not found (may not be installed via Helm)"
            echo ""
            read -p "Was Prometheus Operator installed using kube-prometheus manifests? (yes/no) " -r
            echo
            if [[ $REPLY == "yes" ]]; then
                print_warning "To uninstall, run:"
                echo "  git clone https://github.com/prometheus-operator/kube-prometheus.git"
                echo "  cd kube-prometheus"
                echo "  kubectl delete --ignore-not-found=true -f manifests/"
                echo "  kubectl delete --ignore-not-found=true -f manifests/setup"
            fi
        fi
    fi
else
    print_warning "Skipping Prometheus Operator uninstall"
fi

echo ""
echo "=== Step 3: Clean up namespace ==="
# Check if namespace is empty
REMAINING_RESOURCES=$(kubectl get all -n $NAMESPACE --no-headers 2>/dev/null | wc -l | tr -d ' ')

if [ "$REMAINING_RESOURCES" -eq 0 ]; then
    read -p "Delete empty monitoring namespace? (yes/no) " -r
    echo
    if [[ $REPLY == "yes" ]]; then
        kubectl delete namespace $NAMESPACE
        print_success "Namespace '$NAMESPACE' deleted"
    else
        print_warning "Namespace '$NAMESPACE' retained"
    fi
else
    print_warning "Namespace '$NAMESPACE' still has $REMAINING_RESOURCES resource(s), keeping namespace"
    echo "Remaining resources:"
    kubectl get all -n $NAMESPACE
fi

echo ""
echo "=== Step 4: Clean up local Docker images ==="
read -p "Remove custom nginx Docker image? (yes/no) " -r
echo
if [[ $REPLY == "yes" ]]; then
    if command -v docker &> /dev/null; then
        if docker images | grep -q "custom-nginx"; then
            docker rmi custom-nginx:latest 2>/dev/null || print_warning "Could not remove image (may be in use)"
            print_success "Custom nginx image removed"
        else
            print_warning "Custom nginx image not found"
        fi
    else
        print_warning "Docker not available, skipping image cleanup"
    fi
fi

echo ""
echo "=== Uninstall Complete ==="
echo ""
echo "Summary:"
echo "  - nginx-with-exporter resources removed"
if [[ $REPLY == "yes" ]]; then
    echo "  - Prometheus Operator removed (if selected)"
    echo "  - Custom Docker image removed (if selected)"
fi
echo ""
echo "To verify cleanup:"
echo "  kubectl get all -n monitoring"
echo "  kubectl get namespace monitoring"
echo ""
echo "To reinstall, run:"
echo "  ./quick-start-monitoring.sh"