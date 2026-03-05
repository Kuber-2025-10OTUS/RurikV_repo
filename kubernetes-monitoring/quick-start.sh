#!/bin/bash

# Quick start script to deploy the complete monitoring stack
# This script will:
# 1. Build the custom nginx image
# 2. Install Prometheus Operator
# 3. Deploy nginx with exporter

set -e

echo "=== Kubernetes Monitoring Quick Start ==="
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

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed"
    exit 1
fi
print_success "kubectl is installed"

if ! command -v helm &> /dev/null; then
    print_error "helm is not installed"
    exit 1
fi
print_success "helm is installed"

if ! command -v docker &> /dev/null; then
    print_warning "docker is not installed (optional for building custom image)"
fi

if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi
print_success "Kubernetes cluster is accessible"

echo ""
echo "=== Step 1: Build Custom Nginx Image ==="
read -p "Do you want to build the custom nginx image? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v docker &> /dev/null; then
        echo "Building custom nginx image..."
        cd nginx-custom
        docker build -t custom-nginx:latest .
        cd ..
        print_success "Custom nginx image built successfully"

        # Check if using minikube
        if command -v minikube &> /dev/null; then
            read -p "Are you using minikube? Load image to minikube? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                eval $(minikube docker-env)
                cd nginx-custom
                docker build -t custom-nginx:latest .
                cd ..
                print_success "Image loaded into minikube"
            fi
        fi
    else
        print_warning "Docker not installed, skipping image build"
        print_warning "You'll need to build and push the image to a registry manually"
    fi
else
    print_warning "Skipping custom image build"
    print_warning "Note: The deployment will use nginx:1.25-alpine with ConfigMap"
fi

echo ""
echo "=== Step 2: Install Prometheus Operator ==="
read -p "Install Prometheus Operator? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Installing Prometheus Operator..."
    cd prometheus-operator
    ./install.sh
    cd ..
    print_success "Prometheus Operator installed"
else
    print_warning "Skipping Prometheus Operator installation"
fi

echo ""
echo "=== Step 3: Deploy Nginx with Exporter ==="
read -p "Deploy nginx with exporter? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Deploying nginx with exporter..."
    kubectl apply -f nginx-deployment/
    print_success "Nginx with exporter deployed"

    echo "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=nginx-with-exporter -n monitoring --timeout=120s
    print_success "Pods are ready"
else
    print_warning "Skipping nginx deployment"
fi

echo ""
echo "=== Step 4: Verification ==="
read -p "Run verification script? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./verify.sh
fi

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Next steps:"
echo "1. Access Prometheus UI:"
echo "   kubectl port-forward svc/prometheus-operated -n monitoring 9090:9090"
echo "   Open: http://localhost:9090"
echo ""
echo "2. Access Grafana:"
echo "   kubectl port-forward svc/prometheus-operator-grafana -n monitoring 3000:80"
echo "   Open: http://localhost:3000"
echo "   Credentials: admin / prom-operator"
echo ""
echo "3. Test nginx metrics:"
echo "   kubectl port-forward svc/nginx-with-exporter -n monitoring 8080:80"
echo "   curl http://localhost:8080/nginx_status"
echo ""
echo "4. View metrics in Prometheus:"
echo "   Try queries: nginx_up, nginx_http_requests_total, nginx_connections_active"
echo ""
echo "For more information, see README.md"