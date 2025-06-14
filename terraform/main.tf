terraform {
  required_version = ">= 1.0"
  
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

# Define nodes
locals {
  nodes = {
    pi-master = {
      ip   = "192.168.0.120"
      role = "master"
    }
    pi-worker-1 = {
      ip   = "192.168.0.121"
      role = "worker"
    }
    pi-worker-2 = {
      ip   = "192.168.0.122"
      role = "worker"
    }
    pi-worker-3 = {
      ip   = "192.168.0.123"
      role = "worker"
    }
  }
  
  master_ip = local.nodes["pi-master"].ip
  worker_nodes = {
    for name, node in local.nodes : name => node
    if node.role == "worker"
  }
}

# Generate Ansible inventory
resource "local_file" "ansible_inventory" {
  filename = "../ansible/inventory/hosts.yml"
  content  = templatefile("${path.module}/templates/inventory.yml.tpl", {
    nodes = local.nodes
    ssh_user = var.ssh_user
    ssh_key_path = var.ssh_key_path
  })
}

# Prepare nodes using Ansible
resource "null_resource" "prepare_nodes" {
  depends_on = [local_file.ansible_inventory]
  
  triggers = {
    always_run = timestamp()
  }
  
  provisioner "local-exec" {
    command = "cd ../ansible && ansible-playbook -i inventory/hosts.yml playbooks/prepare-nodes.yml"
  }
}

# Install K3s
resource "null_resource" "install_k3s" {
  depends_on = [null_resource.prepare_nodes]
  
  provisioner "local-exec" {
    command = "cd ../ansible && ansible-playbook -i inventory/hosts.yml playbooks/install-k3s.yml"
  }
}

# Get kubeconfig
resource "null_resource" "get_kubeconfig" {
  depends_on = [null_resource.install_k3s]
  
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ~/.kube
      scp -i ${var.ssh_key_path} ${var.ssh_user}@${local.master_ip}:/etc/rancher/k3s/k3s.yaml ~/.kube/config
      sed -i 's/127.0.0.1/${local.master_ip}/g' ~/.kube/config
    EOT
  }
}

# Deploy K8s resources
module "k3s_cluster" {
  source = "./modules/k3s-cluster"
  
  depends_on = [null_resource.get_kubeconfig]
  
  metallb_ip_range = var.metallb_ip_range
}

module "data_platform" {
  source = "./modules/data-platform"
  
  depends_on = [module.k3s_cluster]
  
  postgres_password = var.postgres_password
  minio_access_key  = var.minio_access_key
  minio_secret_key  = var.minio_secret_key
}