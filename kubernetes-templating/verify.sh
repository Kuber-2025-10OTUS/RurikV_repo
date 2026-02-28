 #!/bin/bash
  echo "=== Task 1: web-server ==="
  echo "Helm release:"
  helm list -n homework
  echo ""
  echo "Pods:"
  kubectl get pods -n homework
  echo ""
  echo "Ingress:"
  kubectl get ingress -n homework
  echo ""
  echo "Values (repo/tag separate, probes config):"
  helm get values web-server -n homework -o yaml | grep -E "repository|tag|probes" -A2

  echo ""
  echo "=== Task 2: Kafka ==="
  echo "DEV namespace:"
  kubectl get pods -n dev
  echo ""
  echo "PROD namespace:"
  kubectl get pods -n prod
  echo ""
  echo "Kafka versions:"
  kubectl get statefulset -A -o yaml | grep "bitnamilegacy/kafka" | sort -u