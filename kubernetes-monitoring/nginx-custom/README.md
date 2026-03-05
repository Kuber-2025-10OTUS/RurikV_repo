# Custom Nginx Image

This custom nginx image is configured to expose metrics via the `stub_status` module for Prometheus monitoring.

## Features

- Based on `nginx:1.25-alpine`
- Exposes `/nginx_status` endpoint for metrics collection
- Health check endpoint at `/health`
- Configured to work with nginx-prometheus-exporter sidecar

## Building the Image

### Using Colima (Recommended for macOS)

If you're using colima, ensure it's running:

```bash
# Start colima if not running
colima start

# Build the image
cd nginx-custom
docker build -t custom-nginx:latest .
```

**Note:** With colima, the image is automatically available to your Kubernetes cluster if you're using the colima Kubernetes runtime.

### Using Minikube

If you're using minikube:

```bash
# Load minikube docker environment
eval $(minikube docker-env)

# Build the image
cd nginx-custom
docker build -t custom-nginx:latest .
```

### Using Docker Desktop or Other Runtimes

```bash
cd nginx-custom
docker build -t custom-nginx:latest .
```

## Testing Locally

```bash
# Run the container
docker run -d -p 8080:80 --name nginx-test custom-nginx:latest

# Test the nginx_status endpoint
curl http://localhost:8080/nginx_status

# Expected output:
# Active connections: 1
# server accepts handled requests
#  1 1 1
# Reading: 0 Writing: 1 Waiting: 0

# Clean up
docker stop nginx-test
docker rm nginx-test
```

## Metrics Available

The stub_status module provides the following metrics:
- Active connections
- Accepted connections
- Handled connections
- Total requests
- Current reading/writing/waiting connections

These metrics will be collected by the nginx-prometheus-exporter and converted to Prometheus format.