output "cluster_id" {
  value = yandex_kubernetes_cluster.this.id
}

output "cluster_name" {
  value = yandex_kubernetes_cluster.this.name
}

output "cluster_endpoint" {
  value = yandex_kubernetes_cluster.this.master[0].external_v4_endpoint
}

output "bucket_name" {
  value = yandex_storage_bucket.loki.bucket
}

output "s3_access_key" {
  value     = yandex_iam_service_account_static_access_key.s3.access_key
  sensitive = true
}

output "s3_secret_key" {
  value     = yandex_iam_service_account_static_access_key.s3.secret_key
  sensitive = true
}

output "kubeconfig_command" {
  value = "yc managed-kubernetes cluster get-credentials ${yandex_kubernetes_cluster.this.name} --external"
}

output "kubectl_get_nodes_command" {
  value = "kubectl get node -o wide --show-labels"
}

output "kubectl_get_taints_command" {
  value = "kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints"
}