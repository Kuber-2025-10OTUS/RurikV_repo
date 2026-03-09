terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }

  required_version = ">= 0.13"
}

provider "yandex" {
  # Use variables if provided, otherwise fall back to environment variables
  cloud_id  = var.yc_cloud_id != null ? var.yc_cloud_id : null
  folder_id = var.yc_folder_id != null ? var.yc_folder_id : null
  zone      = var.yc_zone != null ? var.yc_zone : "ru-central1-a"

  # Authentication:
  # The Yandex provider automatically uses these environment variables:
  # - YC_TOKEN (OAuth token)
  # - YC_SERVICE_ACCOUNT_KEY_FILE (path to service account key file)
  token = var.yc_token != "" ? var.yc_token : null
}