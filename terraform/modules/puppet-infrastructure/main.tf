# Puppet Infrastructure Module
# Generates Bolt inventory and manages Puppet configuration

# Generate Puppet Bolt inventory from Terraform
resource "local_file" "bolt_inventory" {
  filename = "${path.root}/inventory-${var.environment}.yaml"
  content = yamlencode({
    version = 2
    config = {
      transport = "ssh"
      ssh = {
        user = var.ssh_user
        "private-key" = var.ssh_key_path
        "host-key-check" = false
        "run-as" = "root"
      }
    }
    groups = [
      {
        name = "cluster"
        groups = [
          {
            name = "masters"
            targets = [
              for name, node in var.nodes : {
                uri = node.ip
                name = name
                alias = "${name}.${var.cluster_domain}"
                vars = {
                  role = node.role
                  k3s_role = "server"
                  components = node.components
                }
              } if node.role == "master"
            ]
            vars = {
              k3s_server_args = "--disable traefik --disable servicelb"
            }
          },
          {
            name = "workers"
            targets = [
              for name, node in var.nodes : {
                uri = node.ip
                name = name
                alias = "${name}.${var.cluster_domain}"
                vars = {
                  role = node.role
                  k3s_role = "agent"
                  components = node.components
                }
              } if node.role == "worker"
            ]
            vars = {
              k3s_agent_args = ""
            }
          }
        ]
        vars = {
          cluster_name = var.cluster_name
          cluster_domain = var.cluster_domain
          environment = var.environment
        }
      }
    ]
  })
}

# Generate Puppet environment configuration
resource "local_file" "puppet_environment_config" {
  filename = "${path.root}/puppet-env-${var.environment}.yaml"
  content = yamlencode({
    environment = var.puppet_config.environment
    cluster_name = var.cluster_name
    deploy_services = var.puppet_config.deploy_services
    debug_mode = var.puppet_config.debug_mode
    nodes = var.nodes  })
}
