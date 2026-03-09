variable "yc_cloud_id" {
  description = "Yandex Cloud cloud ID (defaults to YC_CLOUD_ID environment variable)"
  type        = string
  default     = null
}

variable "yc_folder_id" {
  description = "Yandex Cloud folder ID (defaults to YC_FOLDER_ID environment variable)"
  type        = string
  default     = null
}

variable "yc_zone" {
  description = "Default availability zone (defaults to YC_ZONE environment variable or ru-central1-a)"
  type        = string
  default     = null
}

variable "yc_token" {
  description = "Yandex Cloud IAM/OAuth token (optional, defaults to YC_TOKEN environment variable)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "logging-cluster"
}

variable "network_name" {
  description = "Network name"
  type        = string
  default     = "logging-network"
}

variable "subnet_name" {
  description = "Subnet name"
  type        = string
  default     = "logging-subnet"
}

variable "subnet_cidr" {
  description = "Subnet CIDR"
  type        = string
  default     = "10.96.0.0/24"
}

variable "k8s_sa_name" {
  description = "Service account name for Kubernetes cluster"
  type        = string
  default     = "k8s-logging-sa"
}

variable "s3_sa_name" {
  description = "Service account name for S3 bucket access"
  type        = string
  default     = "s3-loki-sa"
}

variable "bucket_name" {
  description = "S3 bucket name for Loki logs (must be globally unique)"
  type        = string
  default     = "loki-logs-bucket-otus"
}

variable "worker_node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 1
}

variable "infra_node_count" {
  description = "Number of infrastructure nodes"
  type        = number
  default     = 1
}

variable "worker_node_memory" {
  description = "Worker node RAM in GB"
  type        = number
  default     = 4
}

variable "worker_node_cores" {
  description = "Worker node CPU cores"
  type        = number
  default     = 2
}

variable "infra_node_memory" {
  description = "Infrastructure node RAM in GB"
  type        = number
  default     = 8
}

variable "infra_node_cores" {
  description = "Infrastructure node CPU cores"
  type        = number
  default     = 4
}

variable "node_disk_size" {
  description = "Node boot disk size in GB"
  type        = number
  default     = 64
}

variable "node_disk_type" {
  description = "Node boot disk type"
  type        = string
  default     = "network-ssd"
}

variable "preemptible" {
  description = "Whether nodes should be preemptible"
  type        = bool
  default     = true
}

variable "node_core_fraction" {
  description = "Node CPU core fraction (5, 20, 50, 100)"
  type        = number
  default     = 50
}
