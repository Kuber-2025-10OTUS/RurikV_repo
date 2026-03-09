# Managed Kubernetes cluster
resource "yandex_kubernetes_cluster" "this" {
  name        = var.cluster_name
  network_id  = yandex_vpc_network.this.id
  folder_id   = var.yc_folder_id

  # Master configuration
  master {
    # Zonal master
    zonal {
      zone = var.yc_zone != null ? var.yc_zone : "ru-central1-a"
    }

    # Public IP for API server
    public_ip = true

    # Maintenance policy
    maintenance_policy {
      auto_upgrade = true

      maintenance_window {
        start_time = "03:00"
        duration   = "3h"
      }
    }
  }

  # Service account for cluster operations
  service_account_id      = yandex_iam_service_account.k8s.id
  node_service_account_id = yandex_iam_service_account.k8s.id

  # Kubernetes version
  version = "1.28"

  # Cluster features
  release_channel = "REGULAR"

  # KMS key for secrets encryption
  kms_provider {
    key_id = yandex_kms_symmetric_key.k8s.id
  }
}

# KMS key for Kubernetes secrets encryption
resource "yandex_kms_symmetric_key" "k8s" {
  name              = "${var.cluster_name}-secrets-key"
  default_algorithm = "AES_128"
  rotation_period   = "8760h" # 1 year
}

# Worker node group (for workloads)
resource "yandex_kubernetes_node_group" "worker" {
  cluster_id  = yandex_kubernetes_cluster.this.id
  name        = "worker-nodes"
  description = "Worker nodes for application workloads"

  # Node configuration
  node_resources {
    memory = var.worker_node_memory
    cores  = var.worker_node_cores
  }

  # Boot disk configuration
  boot_disk {
    type = var.node_disk_type
    size = var.node_disk_size
  }

  # Scaling
  scale_policy {
    fixed_scale {
      size = var.worker_node_count
    }
  }

  # Allocate budget for preemptible instances
  allocation_policy {
    location {
      zone = var.yc_zone != null ? var.yc_zone : "ru-central1-a"
    }
  }

  # Instance template
  instance_template {
    platform_id = "standard-v3"

    resources {
      memory        = var.worker_node_memory
      cores         = var.worker_node_cores
      core_fraction = var.node_core_fraction
    }

    boot_disk {
      initialize_params {
        type = var.node_disk_type
        size = var.node_disk_size
      }
    }

    network_interface {
      subnet_ids = [yandex_vpc_subnet.this.id]
      nat        = true
    }

    # Node labels
    labels = {
      "node-role" = "worker"
    }

    # No taints for worker nodes - they accept all workloads
  }

  # Maintenance policy
  maintenance_policy {
    auto_upgrade = true
    auto_repair  = true
  }
}

# Infrastructure node group (for monitoring/logging components)
resource "yandex_kubernetes_node_group" "infra" {
  cluster_id  = yandex_kubernetes_cluster.this.id
  name        = "infra-nodes"
  description = "Infrastructure nodes for monitoring/logging components"

  # Node configuration
  node_resources {
    memory = var.infra_node_memory
    cores  = var.infra_node_cores
  }

  # Boot disk configuration
  boot_disk {
    type = var.node_disk_type
    size = var.node_disk_size
  }

  # Scaling
  scale_policy {
    fixed_scale {
      size = var.infra_node_count
    }
  }

  # Allocate budget for preemptible instances
  allocation_policy {
    location {
      zone = var.yc_zone != null ? var.yc_zone : "ru-central1-a"
    }
  }

  # Instance template
  instance_template {
    platform_id = "standard-v3"

    resources {
      memory        = var.infra_node_memory
      cores         = var.infra_node_cores
      core_fraction = var.node_core_fraction
    }

    boot_disk {
      initialize_params {
        type = var.node_disk_type
        size = var.node_disk_size
      }
    }

    network_interface {
      subnet_ids = [yandex_vpc_subnet.this.id]
      nat        = true
    }

    # Node labels
    labels = {
      "node-role" = "infra"
    }

    # Taint to prevent scheduling of regular workloads
    taint {
      key    = "node-role"
      value  = "infra"
      effect = "NoSchedule"
    }
  }

  # Maintenance policy
  maintenance_policy {
    auto_upgrade = true
    auto_repair  = true
  }
}

# Outputs
output "cluster_id" {
  value = yandex_kubernetes_cluster.this.id
}

output "cluster_name" {
  value = yandex_kubernetes_cluster.this.name
}

output "cluster_endpoint" {
  value = yandex_kubernetes_cluster.this.master[0].public_endpoint
}

# Command to get kubeconfig
output "kubeconfig_command" {
  value = "yc managed-kubernetes cluster get-credentials ${yandex_kubernetes_cluster.this.name} --external"
}