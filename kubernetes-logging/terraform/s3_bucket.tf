# S3 bucket for Loki logs
resource "yandex_storage_bucket" "loki" {
  bucket     = var.bucket_name
  access_key = yandex_iam_service_account_static_access_key.s3.access_key
  secret_key = yandex_iam_service_account_static_access_key.s3.secret_key

  # Set default storage class
  default_storage_class = "STANDARD"

  # Set max size (optional, 0 means unlimited)
  max_size = 1073741824 # 1GB

  # Server-side encryption
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = yandex_kms_symmetric_key.loki.id
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

# KMS key for S3 bucket encryption
resource "yandex_kms_symmetric_key" "loki" {
  name              = "loki-s3-key"
  default_algorithm = "AES_128"
  rotation_period   = "8760h" # 1 year
}

output "bucket_name" {
  value = yandex_storage_bucket.loki.bucket
}