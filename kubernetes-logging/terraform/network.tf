# Network for Kubernetes cluster
resource "yandex_vpc_network" "this" {
  name = var.network_name
}

# Subnet for Kubernetes cluster
resource "yandex_vpc_subnet" "this" {
  name           = var.subnet_name
  zone           = var.yc_zone != null ? var.yc_zone : "ru-central1-a"
  network_id     = yandex_vpc_network.this.id
  v4_cidr_blocks = [var.subnet_cidr]
}