# Kubernetes Monitoring with Prometheus

This project demonstrates how to set up Kubernetes monitoring using Prometheus Operator, nginx with custom metrics, and nginx-prometheus-exporter.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Monitoring Namespace                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │        Prometheus Operator Stack                     │   │
│  │  ┌─────────────┐  ┌──────────────┐  ┌─────────────┐  │   │
│  │  │ Prometheus  │  │ Alertmanager │  │   Grafana   │  │   │
│  │  │   Server    │  │              │  │             │  │   │
│  │  └─────────────┘  └──────────────┘  └─────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
│                         ▲                                   │
│                         │ Scrape Metrics                    │
│                         │                                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  nginx-with-exporter Deployment (2 replicas)         │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │  Pod 1                                         │  │   │
│  │  │  ┌──────────┐         ┌──────────────────┐     │  │   │
│  │  │  │  Nginx   │────────▶│ nginx-prometheus │     │  │   │
│  │  │  │  :80     │ metrics │   exporter :9113 │     │  │   │
│  │  │  └──────────┘         └──────────────────┘     │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │  Pod 2                                         │  │   │
│  │  │  ┌──────────┐         ┌──────────────────┐     │  │   │
│  │  │  │  Nginx   │────────▶│ nginx-prometheus │     │  │   │
│  │  │  │  :80     │ metrics │   exporter :9113 │     │  │   │
│  │  │  └──────────┘         └──────────────────┘     │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. Custom Nginx Image (`nginx-custom/`)
- Custom nginx Docker image based on `nginx:1.25-alpine`
- Configured with `stub_status` module to expose metrics at `/nginx_status`
- Health check endpoint at `/health`

### 2. Prometheus Operator (`prometheus-operator/`)
- Installation scripts for Prometheus Operator using Helm
- Includes Prometheus, Alertmanager, Grafana, Node Exporter, and kube-state-metrics

### 3. Nginx Deployment (`nginx-deployment/`)
- Kubernetes Deployment with nginx and nginx-prometheus-exporter as sidecar container
- ConfigMap with nginx configuration
- Service exposing both HTTP (80) and metrics (9113) ports
- ServiceMonitor for Prometheus Operator to discover and scrape metrics

## Metrics Collected

The nginx-prometheus-exporter collects the following metrics:

- `nginx_connections_active` - Active client connections
- `nginx_connections_accepted` - Accepted client connections
- `nginx_connections_handled` - Handled client connections
- `nginx_connections_reading` - Connections where nginx is reading the request header
- `nginx_connections_writing` - Connections where nginx is writing the response back to the client
- `nginx_connections_waiting` - Keep-alive connections
- `nginx_http_requests_total` - Total HTTP requests
- `nginx_up` - Status of the last scrape (1 = success, 0 = failure)

## Prerequisites

- Kubernetes cluster (colima, minikube, kind, or cloud-based)
- kubectl configured to access your cluster
- Helm 3.x installed
- Docker (for building custom nginx image)
  - **Colima** (recommended for macOS) - provides Docker runtime and optional Kubernetes
  - Or Docker Desktop / minikube / other Docker runtime

## Installation

### Step 1: Build Custom Nginx Image

#### Using Colima (Recommended for macOS)

If you're using colima, ensure it's running:

```bash
# Start colima if not running
colima start

# Build the custom nginx image
cd nginx-custom
docker build -t custom-nginx:latest .
cd ..
```

**Note:** With colima, the image is automatically available to your Kubernetes cluster if you're using the colima Kubernetes runtime.

#### Using Minikube

If you're using minikube:

```bash
# Load minikube docker environment
eval $(minikube docker-env)

# Build the image
cd nginx-custom
docker build -t custom-nginx:latest .
cd ..
```

#### Using Container Registry

Alternatively, build and push to a registry:

```bash
cd nginx-custom
docker build -t your-registry/custom-nginx:latest .
docker push your-registry/custom-nginx:latest
cd ..

# Update deployment.yaml to use your-registry/custom-nginx:latest
```

### Step 2: Install Prometheus Operator

```bash
cd prometheus-operator
./install.sh
cd ..
```

This will install:
- Prometheus Operator
- Prometheus server
- Alertmanager
- Grafana
- Node Exporter
- kube-state-metrics

### Step 3: Deploy Nginx with Exporter

```bash
# Apply all manifests
kubectl apply -f nginx-deployment/

# Verify deployment
kubectl get all -n monitoring -l app=nginx-with-exporter
```

### Step 4: Verify Metrics Collection

```bash
# Port-forward to Prometheus
kubectl port-forward svc/prometheus-operated -n monitoring 9090:9090

# Open Prometheus UI at http://localhost:9090
# Try queries:
# - nginx_up
# - nginx_http_requests_total
# - nginx_connections_active
```

## Verification

### Check Pods Status

```bash
# Check monitoring namespace pods
kubectl get pods -n monitoring

# Check nginx deployment
kubectl get pods -n monitoring -l app=nginx-with-exporter

# Check logs
kubectl logs -n monitoring -l app=nginx-with-exporter -c nginx
kubectl logs -n monitoring -l app=nginx-with-exporter -c nginx-exporter
```

### Test Nginx Metrics Endpoint

```bash
# Port-forward to nginx service
kubectl port-forward svc/nginx-with-exporter -n monitoring 8080:80

# Test stub_status endpoint
curl http://localhost:8080/nginx_status

# Test health endpoint
curl http://localhost:8080/health
```

### Test Prometheus Exporter

```bash
# Port-forward to metrics endpoint
kubectl port-forward svc/nginx-with-exporter -n monitoring 9113:9113

# Get Prometheus metrics
curl http://localhost:9113/metrics
```

### Check ServiceMonitor

```bash
# List ServiceMonitors
kubectl get servicemonitor -n monitoring

# Describe ServiceMonitor
kubectl describe servicemonitor nginx-with-exporter -n monitoring
```

### Access Grafana

```bash
# Port-forward to Grafana
kubectl port-forward svc/prometheus-operator-grafana -n monitoring 3000:80

# Open Grafana at http://localhost:3000
# Get credentials (username: admin):
kubectl get secret prometheus-operator-grafana -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d && echo
```

You can import nginx dashboards or create your own to visualize metrics:
- Grafana Dashboard for nginx: Dashboard ID `12708` or `12902`

## Monitoring in Action

Once everything is deployed, you can:

1. **View metrics in Prometheus UI**
   ```bash
   kubectl port-forward svc/prometheus-operated -n monitoring 9090:9090
   ```
   Navigate to http://localhost:9090 and try queries:
   - `nginx_up`
   - `rate(nginx_http_requests_total[5m])`
   - `nginx_connections_active`

2. **Create alerts** (optional)
   Create PrometheusRule resources to alert on nginx metrics

3. **Visualize in Grafana**
   Import pre-built nginx dashboards or create custom ones

## Troubleshooting

### Nginx exporter not scraping metrics

1. Check nginx stub_status is accessible:
   ```bash
   kubectl exec -it -n monitoring <nginx-pod> -c nginx -- wget -O- http://localhost:80/nginx_status
   ```

2. Check exporter logs:
   ```bash
   kubectl logs -n monitoring <nginx-pod> -c nginx-exporter
   ```

### Prometheus not discovering targets

1. Check ServiceMonitor label matches Prometheus selector:
   ```bash
   kubectl get prometheus -n monitoring -o yaml | grep serviceMonitorSelector -A 5
   ```

2. Verify ServiceMonitor exists:
   ```bash
   kubectl get servicemonitor -n monitoring
   ```

3. Check Prometheus targets:
   - Port-forward to Prometheus UI (9090)
   - Go to Status → Targets
   - Look for your nginx-with-exporter target

### Metrics not appearing

1. Verify Service has correct port name:
   ```bash
   kubectl describe svc nginx-with-exporter -n monitoring
   ```

   Port name should be `metrics` to match ServiceMonitor.

2. Check pod labels match ServiceMonitor selector:
   ```bash
   kubectl get pods -n monitoring -l app=nginx-with-exporter --show-labels
   ```

## Cleanup

### Using the Uninstall Script (Recommended)

The easiest way to clean up is to use the provided uninstall script:

```bash
./uninstall-monitoring.sh
```

This interactive script will:
- Remove all nginx-with-exporter resources
- Optionally uninstall Prometheus Operator
- Clean up the monitoring namespace
- Optionally remove custom Docker images

### Manual Cleanup

If you prefer to clean up manually:

```bash
# Remove nginx deployment
kubectl delete -f nginx-deployment/

# Remove Prometheus Operator (if installed via Helm)
helm uninstall prometheus-operator -n monitoring
kubectl delete namespace monitoring

# Or if using manifests
cd prometheus-operator
kubectl delete -f https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/main/manifests/setup
kubectl delete -f https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/main/manifests/
```

## Resources

- [Prometheus Operator Documentation](https://prometheus-operator.dev/)
- [nginx-prometheus-exporter GitHub](https://github.com/nginxinc/nginx-prometheus-exporter)
- [kube-prometheus-stack Helm Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

