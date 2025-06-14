resource "null_resource" "puppet_server" {
  # Deploy Puppet server on a dedicated node or use Puppet Enterprise
  provisioner "remote-exec" {
    inline = [
      "curl -k https://puppet.com/download-puppet-enterprise | sudo bash",
      "sudo puppet config set server puppet.${var.cluster_domain}",
      "sudo puppet config set certname ${var.puppet_server_hostname}"
    ]
    
    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.ssh_key_path)
      host        = var.puppet_server_ip
    }
  }
}

# Generate Puppet Bolt inventory from Terraform
resource "local_file" "bolt_inventory" {
  filename = "../inventory.yaml"
  content  = yamlencode({
    version = 2
    groups = [
      {
        name = "masters"
        targets = [
          for name, node in local.nodes : {
            uri  = "${node.ip}"
            name = name
            vars = {
              role = node.role
              ip   = node.ip
            }
          } if node.role == "master"
        ]
      },
      {
        name = "workers"
        targets = [
          for name, node in local.nodes : {
            uri  = "${node.ip}"
            name = name
            vars = {
              role = node.role
              ip   = node.ip
            }
          } if node.role == "worker"
        ]
      }
    ]
    config = {
      ssh = {
        user        = var.ssh_user
        private-key = var.ssh_key_path
        host-key-check = false
      }
    }
  })
}

# Run Puppet Bolt plan
resource "null_resource" "run_puppet_deployment" {
  depends_on = [local_file.bolt_inventory]
  
  triggers = {
    always_run = timestamp()
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      cd ../puppet
      bolt plan run pi_cluster_automation::deploy \
        --inventoryfile ../inventory.yaml \
        environment=${var.environment}
    EOT
  }
}