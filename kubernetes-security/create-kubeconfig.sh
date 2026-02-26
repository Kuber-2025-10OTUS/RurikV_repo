#!/bin/bash
# Script to create kubeconfig for service account 'cd' in namespace 'homework'

set -e

SA_NAME="cd"
NAMESPACE="homework"
CONTEXT_NAME="homework-cd"
KUBECONFIG_OUTPUT="kubeconfig"

# Get cluster info
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
CLUSTER_URL=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CLUSTER_CA=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

# Get service account token (for Kubernetes < 1.24) or create a token request
echo "Creating token for service account $SA_NAME..."

# For Kubernetes 1.24+, we need to create a TokenRequest
TOKEN=$(kubectl create token $SA_NAME -n $NAMESPACE --duration=24h)

# Create kubeconfig file
cat > $KUBECONFIG_OUTPUT << EOF
apiVersion: v1
kind: Config
current-context: $CONTEXT_NAME
contexts:
- name: $CONTEXT_NAME
  context:
    cluster: $CLUSTER_NAME
    namespace: $NAMESPACE
    user: $SA_NAME
clusters:
- name: $CLUSTER_NAME
  cluster:
    server: $CLUSTER_URL
    certificate-authority-data: $CLUSTER_CA
users:
- name: $SA_NAME
  user:
    token: $TOKEN
EOF

echo "Kubeconfig created: $KUBECONFIG_OUTPUT"
echo "Test with: kubectl --kubeconfig=$KUBECONFIG_OUTPUT get pods"
