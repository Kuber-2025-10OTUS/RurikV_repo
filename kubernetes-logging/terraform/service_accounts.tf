# Service account for Kubernetes cluster
resource "yandex_iam_service_account" "k8s" {
  name        = var.k8s_sa_name
  description = "Service account for Kubernetes cluster ${var.cluster_name}"
}

# Assign roles to Kubernetes service account
resource "yandex_resourcemanager_folder_iam_member" "k8s_cluster_agent" {
  folder_id = var.yc_folder_id
  role      = "k8s.clusters.agent"
  member    = "serviceAccount:${yandex_iam_service_account.k8s.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_vpc_public_admin" {
  folder_id = var.yc_folder_id
  role      = "vpc.publicAdmin"
  member    = "serviceAccount:${yandex_iam_service_account.k8s.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_images_puller" {
  folder_id = var.yc_folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.k8s.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_encrypter_decrypter" {
  folder_id = var.yc_folder_id
  role      = "kms.keys.encrypterDecrypter"
  member    = "serviceAccount:${yandex_iam_service_account.k8s.id}"
}

# Service account for S3 bucket (Loki logs)
resource "yandex_iam_service_account" "s3" {
  name        = var.s3_sa_name
  description = "Service account for S3 bucket access (Loki logs)"
}

# Assign roles to S3 service account
resource "yandex_resourcemanager_folder_iam_member" "s3_storage_editor" {
  folder_id = var.yc_folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.s3.id}"
}

# Create static access key for S3 service account
resource "yandex_iam_service_account_static_access_key" "s3" {
  service_account_id = yandex_iam_service_account.s3.id
  description        = "Static access key for S3 service account"
}
