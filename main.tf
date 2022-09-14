# Provider
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

provider "yandex" {
  token     = "${file("./provider.txt")}"
  cloud_id  = "b1gvfblsfup1uvnclqr1"
  folder_id = "b1ghbguaadhn21pv90pb"
}

# VM's
resource "yandex_compute_instance" "nginx1" {
  name = "nginx1"
  zone = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd87kbts7j40q5b9rpjr"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
    user-data = "${file("./meta.txt")}"
  }

}

resource "yandex_compute_instance" "nginx2" {
  name = "nginx2"
  zone = "ru-central1-b"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd87kbts7j40q5b9rpjr"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-2.id
    nat       = true
  }

  metadata = {
    user-data = "${file("./meta.txt")}"
  }

}

resource "yandex_compute_instance" "prometeus" {
  name = "prometeus"
  zone = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd87kbts7j40q5b9rpjr"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-3.id
    nat       = true
  }

  metadata = {
    user-data = "${file("./meta.txt")}"
  }

}

resource "yandex_compute_instance" "grafana" {
  name = "grafana"
  zone = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd87kbts7j40q5b9rpjr"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.public.id
    nat       = true
  }

  metadata = {
    user-data = "${file("./meta.txt")}"
  }

}

resource "yandex_compute_instance" "elasticsearch" {
  name = "elasticsearch"
  zone = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd87kbts7j40q5b9rpjr"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-4.id
    nat       = true
  }

  metadata = {
    user-data = "${file("./meta.txt")}"
  }

}

resource "yandex_compute_instance" "kibana" {
  name = "kibana"
  zone = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd87kbts7j40q5b9rpjr"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.public.id
    nat       = true
  }

  metadata = {
    user-data = "${file("./meta.txt")}"
  }

}


# Net
resource "yandex_vpc_network" "network-1" {
  name = "nginx_network"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet_nginx1"
  network_id     = yandex_vpc_network.network-1.id
  zone           = "ru-central1-a"
  v4_cidr_blocks = ["10.129.0.0/24"]
}

resource "yandex_vpc_subnet" "subnet-2" {
  name           = "subnet_nginx2"
  network_id     = yandex_vpc_network.network-1.id
  zone           = "ru-central1-b"
  v4_cidr_blocks = ["10.130.0.0/24"]
}

resource "yandex_vpc_subnet" "public" {
  name           = "subnet_public"
  network_id     = yandex_vpc_network.network-1.id
  zone           = "ru-central1-a"
  v4_cidr_blocks = ["10.128.0.0/24"]
}

resource "yandex_vpc_subnet" "subnet-3" {
  name           = "subnet_prometeus"
  network_id     = yandex_vpc_network.network-1.id
  zone           = "ru-central1-a"
  v4_cidr_blocks = ["10.131.0.0/24"]
}

resource "yandex_vpc_subnet" "subnet-4" {
  name           = "subnet_elasticsearch"
  network_id     = yandex_vpc_network.network-1.id
  zone           = "ru-central1-a"
  v4_cidr_blocks = ["10.126.0.0/24"]
}


# Target group
resource "yandex_alb_target_group" "target" {
  name           = "nginx-target"

  target {
    subnet_id    = "${yandex_vpc_subnet.subnet-1.id}"
    ip_address   = "${yandex_compute_instance.nginx1.network_interface.0.ip_address}"
  }

  target {
    subnet_id    = "${yandex_vpc_subnet.subnet-2.id}"
    ip_address   = "${yandex_compute_instance.nginx2.network_interface.0.ip_address}"
  }
}

# Backend group
resource "yandex_alb_backend_group" "backend-group" {
  name      = "backend-group"

  http_backend {
    name = "http-backend"
    weight = 1
    port = 80
    target_group_ids = ["${yandex_alb_target_group.target.id}"]
    load_balancing_config {
      panic_threshold = 50
    }    
    healthcheck {
      timeout = "10s"
      interval = "2s"
      http_healthcheck {
        path  = "/"
      }
    }
  }
}

# Http router
resource "yandex_alb_http_router" "http_router" {
  name   = "router"
  labels = {
    tf-label    = "tf-label-value"
    empty-label = ""
  }
}

resource "yandex_alb_virtual_host" "virtual-host" {
  name           = "http-host"
  http_router_id = "${yandex_alb_http_router.http_router.id}"
    route {
    name = "route"
    http_route {
      http_route_action {
        backend_group_id = "${yandex_alb_backend_group.backend-group.id}"
        timeout          = "3s"
      }
    }
  }
} 

#L7 balancer
resource "yandex_alb_load_balancer" "balancer" {
  name        = "balancer"
  network_id  = "${yandex_vpc_network.network-1.id}"

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = "${yandex_vpc_subnet.public.id}" 
    }
  }

  listener {
    name = "listener"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [ 80 ]
    }
    http {
      handler {
        http_router_id = "${yandex_alb_http_router.http_router.id}"
      }
    }
  }
}

# Output
output "internal_ip_address_vm_1" {
  value = yandex_compute_instance.nginx1.network_interface.0.ip_address
}
output "internal_ip_address_vm_2" {
  value = yandex_compute_instance.nginx2.network_interface.0.ip_address
}
output "external_ip_address_vm_1" {
  value = yandex_compute_instance.nginx1.network_interface.0.nat_ip_address
}
output "external_ip_address_vm_2" {
  value = yandex_compute_instance.nginx2.network_interface.0.nat_ip_address
}