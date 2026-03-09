  # Upgrade Loki with new configuration
  helm upgrade --install loki grafana/loki \
    -n monitoring \
    -f ../helm-charts/values-loki.yaml

  # Upgrade Promtail with new configuration
  helm upgrade --install promtail grafana/promtail \
    -n monitoring \
    -f ../helm-charts/values-promtail.yaml

  # Upgrade Grafana with new datasource configuration
  helm upgrade --install grafana grafana/grafana \
    -n monitoring \
    -f ../helm-charts/values-grafana.yaml