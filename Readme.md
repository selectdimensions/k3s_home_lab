*Thinking...*

> The user wants to switch from Ansible to Puppet for configuration management since Puppet is compatible with Windows, Mac, and Ubuntu. I need to restructure the entire project to use Puppet instead of Ansible while maintaining all the professional DevOps practices, CI/CD pipelines, and enhanced features they requested.
> 
> I'll need to:
> 1. Replace all Ansible components with Puppet equivalents
> 2. Maintain the same level of sophistication and features
> 3. Keep the Terraform parts
> 4. Update the CI/CD pipelines to work with Puppet
> 5. Ensure the structure is comprehensive and production-ready
> 6. Include Puppet modules, manifests, Hiera for data management
> 7. Add Puppet testing with rspec-puppet
> 8. Include Puppet Bolt for orchestration tasks

I'll redesign your Pi Cluster project using Puppet for cross-platform compatibility while maintaining professional DevOps practices.

## Enhanced Project Structure with Puppet

```
pi-cluster-automation/
├── .github/
│   ├── workflows/
│   │   ├── terraform-ci.yml
│   │   ├── puppet-ci.yml
│   │   ├── k8s-apps-cd.yml
│   │   └── security-scan.yml
│   └── dependabot.yml
├── terraform/
│   ├── environments/
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   ├── modules/
│   │   ├── puppet-infrastructure/
│   │   ├── k3s-cluster/
│   │   ├── monitoring/
│   │   ├── gitops/
│   │   └── backup/
│   └── backend.tf
├── puppet/
│   ├── bolt-project.yaml
│   ├── Puppetfile
│   ├── hiera.yaml
│   ├── data/
│   │   ├── common.yaml
│   │   ├── nodes/
│   │   └── environments/
│   ├── site-modules/
│   │   ├── profiles/
│   │   ├── roles/
│   │   └── pi_cluster/
│   ├── manifests/
│   │   └── site.pp
│   ├── plans/
│   │   ├── deploy.pp
│   │   └── restore.pp
│   ├── tasks/
│   │   └── health_check.json
│   └── spec/
├── k8s/
│   ├── base/
│   ├── overlays/
│   └── applications/
├── scripts/
│   ├── setup/
│   ├── backup/
│   └── disaster-recovery/
├── tests/
│   ├── terraform/
│   ├── puppet/
│   └── integration/
├── docs/
│   ├── architecture/
│   ├── runbooks/
│   └── puppet-guides/
├── monitoring/
│   ├── dashboards/
│   └── alerts/
├── inventory.yaml
├── Makefile
└── README.md
```

## 1. Puppet Configuration

### puppet/bolt-project.yaml

```yaml
name: pi_cluster_automation
modules:
  - git: https://github.com/puppetlabs/puppetlabs-stdlib.git
    ref: 8.5.0
  - git: https://github.com/puppetlabs/puppetlabs-docker.git
    ref: 6.0.0
  - git: https://github.com/puppetlabs/puppetlabs-kubernetes.git
    ref: 7.1.0

plans:
  - pi_cluster_automation::deploy
  - pi_cluster_automation::restore
  - pi_cluster_automation::health_check

tasks:
  - pi_cluster_automation::node_info
  - pi_cluster_automation::k3s_status

inventory-config:
  ssh:
    user: hezekiah
    private-key: ~/.ssh/keys/hobby/pi_k3s_cluster
    host-key-check: false
```

### puppet/Puppetfile

```ruby
forge 'https://forge.puppet.com'

# Core modules
mod 'puppetlabs-stdlib', '8.5.0'
mod 'puppetlabs-concat', '7.3.3'
mod 'puppetlabs-firewall', '3.6.0'
mod 'puppetlabs-apt', '9.0.2'
mod 'puppetlabs-vcsrepo', '5.4.0'
mod 'puppetlabs-docker', '6.0.0'
mod 'puppetlabs-kubernetes', '7.1.0'
mod 'puppetlabs-helm', '0.2.0'

# Additional modules for Pi cluster
mod 'puppet-systemd', '3.10.0'
mod 'puppet-archive', '6.1.1'
mod 'puppet-python', '6.3.0'
mod 'camptocamp-kmod', '3.2.0'
mod 'puppet-alternatives', '4.1.0'

# Monitoring modules
mod 'puppet-prometheus', '12.4.0'
mod 'puppet-grafana', '11.1.0'
```

### puppet/hiera.yaml

```yaml
---
version: 5

defaults:
  datadir: data
  data_hash: yaml_data

hierarchy:
  - name: "Per-node data"
    paths:
      - "nodes/%{facts.networking.hostname}.yaml"
      - "nodes/%{facts.networking.fqdn}.yaml"
  
  - name: "Per-environment data"
    paths:
      - "environments/%{environment}/common.yaml"
      - "environments/%{environment}/%{facts.os.family}.yaml"
  
  - name: "Per-OS defaults"
    paths:
      - "os/%{facts.os.family}.yaml"
      - "os/%{facts.os.name}/%{facts.os.release.major}.yaml"
  
  - name: "Common data"
    path: "common.yaml"
```

### puppet/data/common.yaml

```yaml
---
# Common configuration for all nodes
pi_cluster::cluster_name: 'pi-k3s-cluster'
pi_cluster::cluster_domain: 'cluster.local'
pi_cluster::timezone: 'UTC'

# Network configuration
pi_cluster::network::cidr: '192.168.0.0/24'
pi_cluster::network::gateway: '192.168.0.1'
pi_cluster::network::dns_servers:
  - '8.8.8.8'
  - '1.1.1.1'

# K3s configuration
pi_cluster::k3s::version: 'v1.28.4+k3s1'
pi_cluster::k3s::disable_components:
  - 'traefik'
  - 'servicelb'

# MetalLB configuration
pi_cluster::metallb::version: '0.13.12'
pi_cluster::metallb::ip_range: '192.168.0.200-192.168.0.250'

# Storage configuration
pi_cluster::storage::default_class: 'local-path'

# Backup configuration
pi_cluster::backup::schedule: '0 2 * * *'
pi_cluster::backup::retention_days: 30

# Security settings
pi_cluster::security::enable_firewall: true
pi_cluster::security::fail2ban::enabled: true
pi_cluster::security::ssh::permit_root_login: false
```

### puppet/site-modules/roles/manifests/pi_master.pp

```puppet
# Role for Pi Master Node
class roles::pi_master {
  include profiles::base
  include profiles::networking
  include profiles::security
  include profiles::k3s_server
  include profiles::monitoring_server
  include profiles::backup_server
  
  Class['profiles::base']
  -> Class['profiles::networking']
  -> Class['profiles::security']
  -> Class['profiles::k3s_server']
  -> Class['profiles::monitoring_server']
  -> Class['profiles::backup_server']
}
```

### puppet/site-modules/roles/manifests/pi_worker.pp

```puppet
# Role for Pi Worker Node
class roles::pi_worker {
  include profiles::base
  include profiles::networking
  include profiles::security
  include profiles::k3s_agent
  include profiles::monitoring_agent
  
  Class['profiles::base']
  -> Class['profiles::networking']
  -> Class['profiles::security']
  -> Class['profiles::k3s_agent']
  -> Class['profiles::monitoring_agent']
}
```

### puppet/site-modules/profiles/manifests/base.pp

```puppet
# Base profile for all Pi nodes
class profiles::base (
  String $timezone = lookup('pi_cluster::timezone'),
) {
  # Set timezone
  class { 'timezone':
    timezone => $timezone,
  }
  
  # Essential packages
  $base_packages = [
    'curl',
    'wget',
    'git',
    'vim',
    'htop',
    'iotop',
    'ncdu',
    'tmux',
    'python3-pip',
    'jq',
  ]
  
  package { $base_packages:
    ensure => present,
  }
  
  # Configure system limits
  file { '/etc/security/limits.d/pi-cluster.conf':
    ensure  => file,
    content => template('profiles/limits.conf.erb'),
  }
  
  # Enable cgroups for K3s
  augeas { 'enable_cgroups':
    context => '/files/boot/cmdline.txt',
    changes => [
      'set /files/boot/cmdline.txt/1 "$(cat /boot/cmdline.txt) cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1"',
    ],
    onlyif  => 'match /files/boot/cmdline.txt/*[. =~ regexp(".*cgroup_enable=memory.*")] size == 0',
    notify  => Reboot['after_cgroups'],
  }
  
  reboot { 'after_cgroups':
    when => refreshed,
  }
  
  # Disable swap
  exec { 'disable_swap':
    command => '/sbin/dphys-swapfile swapoff && /sbin/dphys-swapfile uninstall',
    onlyif  => '/usr/bin/test -f /var/swap',
  }
  
  service { 'dphys-swapfile':
    ensure => stopped,
    enable => false,
  }
}
```

### puppet/site-modules/profiles/manifests/k3s_server.pp

```puppet
# K3s server profile
class profiles::k3s_server (
  String $version = lookup('pi_cluster::k3s::version'),
  Array[String] $disable_components = lookup('pi_cluster::k3s::disable_components'),
) {
  
  # Install K3s server
  exec { 'install_k3s_server':
    command => @("CMD"/L),
      curl -sfL https://get.k3s.io | \
      INSTALL_K3S_VERSION=${version} \
      sh -s - server \
      --write-kubeconfig-mode 644 \
      --disable ${disable_components.join(' --disable ')} \
      --node-name ${facts['networking']['hostname']}
      | CMD
    path    => ['/usr/bin', '/usr/local/bin'],
    creates => '/usr/local/bin/k3s',
  }
  
  # Ensure K3s service is running
  service { 'k3s':
    ensure  => running,
    enable  => true,
    require => Exec['install_k3s_server'],
  }
  
  # Export node token for workers
  file { '/etc/rancher/k3s/node-token':
    ensure  => file,
    mode    => '0640',
    require => Service['k3s'],
  }
  
  # Configure kubectl for local use
  file { '/root/.kube':
    ensure => directory,
  }
  
  file { '/root/.kube/config':
    ensure  => link,
    target  => '/etc/rancher/k3s/k3s.yaml',
    require => [File['/root/.kube'], Service['k3s']],
  }
}
```

### puppet/plans/deploy.pp

```puppet
# Deployment plan for Pi cluster
plan pi_cluster_automation::deploy (
  TargetSpec $targets,
  String $environment = 'prod',
  Boolean $skip_k3s = false,
) {
  # Gather facts
  $target_facts = run_task('facts', $targets)
  
  # Group targets by role
  $masters = $targets.filter |$target| {
    $target.vars['role'] == 'master'
  }
  
  $workers = $targets.filter |$target| {
    $target.vars['role'] == 'worker'
  }
  
  # Phase 1: Base configuration
  out::message("Phase 1: Configuring base system on all nodes")
  apply($targets, _catch_errors => false) {
    include profiles::base
    include profiles::networking
    include profiles::security
  }
  
  # Phase 2: Install K3s on master
  unless $skip_k3s {
    out::message("Phase 2: Installing K3s on master nodes")
    apply($masters, _catch_errors => false) {
      include profiles::k3s_server
    }
    
    # Get token from master
    $token_result = run_command('cat /var/lib/rancher/k3s/server/node-token', $masters)
    $k3s_token = $token_result.first.stdout.chomp
    $master_ip = $masters.first.vars['ip']
    
    # Phase 3: Install K3s on workers
    out::message("Phase 3: Installing K3s on worker nodes")
    apply($workers, _catch_errors => false) {
      class { 'profiles::k3s_agent':
        server_url => "https://${master_ip}:6443",
        token      => $k3s_token,
      }
    }
  }
  
  # Phase 4: Deploy cluster services
  out::message("Phase 4: Deploying cluster services")
  run_task('pi_cluster_automation::deploy_services', $masters.first, {
    'environment' => $environment,
  })
  
  # Phase 5: Verify deployment
  out::message("Phase 5: Verifying deployment")
  $health_check = run_task('pi_cluster_automation::health_check', $targets)
  
  out::message("Deployment complete!")
  return $health_check
}
```

## 2. Enhanced GitHub Actions with Puppet

### .github/workflows/puppet-ci.yml

```yaml
name: Puppet CI/CD

on:
  pull_request:
    paths:
      - 'puppet/**'
      - '.github/workflows/puppet-ci.yml'
  push:
    branches:
      - main
    paths:
      - 'puppet/**'

env:
  PUPPET_VERSION: '7.26.0'
  PDK_VERSION: '3.0.0'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.1'
          bundler-cache: true

      - name: Install PDK
        run: |
          wget https://puppet.com/download-puppet-development-kit
          sudo dpkg -i puppet-development-kit_${PDK_VERSION}-1focal_amd64.deb

      - name: Validate Puppet manifests
        run: |
          cd puppet
          pdk validate

      - name: Run Puppet lint
        run: |
          cd puppet
          pdk validate puppet

      - name: Check Puppet style
        run: |
          cd puppet
          pdk validate ruby

  test:
    needs: validate
    runs-on: ubuntu-latest
    strategy:
      matrix:
        puppet_version: ['7.26.0', '8.0.0']
        os: ['debian-11', 'ubuntu-22.04']
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.1'

      - name: Install dependencies
        run: |
          cd puppet
          bundle install
          
      - name: Run rspec tests
        run: |
          cd puppet
          bundle exec rake spec
        env:
          PUPPET_VERSION: ${{ matrix.puppet_version }}
          FACTER_os_family: ${{ matrix.os }}

      - name: Run acceptance tests
        run: |
          cd puppet
          bundle exec rake beaker
        if: github.event_name == 'push'

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    strategy:
      matrix:
        environment: [dev, staging, prod]
      max-parallel: 1
    environment: ${{ matrix.environment }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Puppet Bolt
        run: |
          wget -O - https://apt.puppet.com/puppet-tools-release-focal.deb | sudo dpkg -i -
          sudo apt-get update
          sudo apt-get install -y puppet-bolt

      - name: Configure SSH key
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.PI_CLUSTER_SSH_KEY }}" > ~/.ssh/pi_cluster_key
          chmod 600 ~/.ssh/pi_cluster_key

      - name: Run Puppet Bolt deployment
        run: |
          cd puppet
          bolt plan run pi_cluster_automation::deploy \
            --targets @../inventory.yaml \
            --inventoryfile ../inventory.yaml \
            environment=${{ matrix.environment }} \
            --run-as root \
            --no-host-key-check
```

## 3. Terraform Integration with Puppet

### terraform/modules/puppet-infrastructure/main.tf

```hcl
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
```

## 4. Cross-Platform Management Scripts

### scripts/setup/install-puppet-agent.ps1

```powershell
# PowerShell script for Windows nodes
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$PuppetServer,
    
    [Parameter(Mandatory=$true)]
    [string]$Environment = "prod",
    
    [string]$PuppetVersion = "7.26.0"
)

# Download and install Puppet agent
$puppetMSI = "puppet-agent-$PuppetVersion-x64.msi"
$downloadUrl = "https://downloads.puppet.com/windows/puppet7/$puppetMSI"

Write-Host "Downloading Puppet Agent..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $puppetMSI

Write-Host "Installing Puppet Agent..."
Start-Process msiexec.exe -ArgumentList "/i $puppetMSI /qn /norestart PUPPET_MASTER_SERVER=$PuppetServer" -Wait

# Configure Puppet
$puppetConf = @"
[main]
server = $PuppetServer
environment = $Environment
runinterval = 30m
"@

Set-Content -Path "C:\ProgramData\PuppetLabs\puppet\etc\puppet.conf" -Value $puppetConf

# Start Puppet service
Start-Service -Name puppet
Set-Service -Name puppet -StartupType Automatic

Write-Host "Puppet Agent installed and configured successfully!"
```

### scripts/setup/install-puppet-agent.sh

```bash
#!/bin/bash
# Cross-platform Puppet agent installation script

set -euo pipefail

PUPPET_SERVER=${1:-puppet.cluster.local}
ENVIRONMENT=${2:-prod}
OS_TYPE=$(uname -s)

install_puppet_debian() {
    wget https://apt.puppet.com/puppet7-release-$(lsb_release -cs).deb
    sudo dpkg -i puppet7-release-$(lsb_release -cs).deb
    sudo apt-get update
    sudo apt-get install -y puppet-agent
}

install_puppet_redhat() {
    sudo rpm -Uvh https://yum.puppet.com/puppet7-release-el-$(rpm -E %{rhel}).noarch.rpm
    sudo yum install -y puppet-agent
}

install_puppet_macos() {
    brew install --cask puppet-agent
}

configure_puppet() {
    sudo /opt/puppetlabs/bin/puppet config set server $PUPPET_SERVER --section main
    sudo /opt/puppetlabs/bin/puppet config set environment $ENVIRONMENT --section main
    sudo /opt/puppetlabs/bin/puppet config set runinterval 30m --section main
}

case "$OS_TYPE" in
    Linux)
        if [ -f /etc/debian_version ]; then
            install_puppet_debian
        elif [ -f /etc/redhat-release ]; then
            install_puppet_redhat
        fi
        ;;
    Darwin)
        install_puppet_macos
        ;;
    *)
        echo "Unsupported OS: $OS_TYPE"
        exit 1
        ;;
esac

configure_puppet

# Enable and start Puppet
sudo /opt/puppetlabs/bin/puppet resource service puppet ensure=running enable=true

echo "Puppet agent installed and configured successfully!"
```

## 5. Enhanced Puppet Testing

### puppet/spec/spec_helper.rb

```ruby
require 'puppetlabs_spec_helper/module_spec_helper'
require 'rspec-puppet-facts'

include RspecPuppetFacts

default_facts = {
  puppetversion: Puppet.version,
  facterversion: Facter.version,
}

default_fact_files = [
  File.expand_path(File.join(File.dirname(__FILE__), 'default_facts.yml')),
  File.expand_path(File.join(File.dirname(__FILE__), 'default_module_facts.yml')),
]

default_fact_files.each do |f|
  next unless File.exist?(f) && File.readable?(f) && File.size?(f)

  begin
    default_facts.merge!(YAML.safe_load(File.read(f), [], [], true))
  rescue => e
    RSpec.configuration.reporter.message "WARNING: Unable to load #{f}: #{e}"
  end
end

RSpec.configure do |c|
  c.default_facts = default_facts
  c.before :each do
    Puppet.settings[:strict] = :error
  end
  c.filter_run_excluding(bolt: true) unless ENV['GEM_BOLT']
  c.after(:suite) do
  end
end
```

### puppet/spec/classes/profiles/k3s_server_spec.rb

```ruby
require 'spec_helper'

describe 'profiles::k3s_server' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:params) do
        {
          version: 'v1.28.4+k3s1',
          disable_components: ['traefik', 'servicelb']
        }
      end

      it { is_expected.to compile }

      it { is_expected.to contain_exec('install_k3s_server')
        .with_command(/INSTALL_K3S_VERSION=v1.28.4\+k3s1/)
        .with_creates('/usr/local/bin/k3s')
      }

      it { is_expected.to contain_service('k3s')
        .with_ensure('running')
        .with_enable(true)
      }

      it { is_expected.to contain_file('/root/.kube/config')
        .with_ensure('link')
        .with_target('/etc/rancher/k3s/k3s.yaml')
      }
    end
  end
end
```

## 6. Enhanced Makefile with Puppet

```makefile
.PHONY: help init validate plan apply destroy test backup restore puppet-deploy

ENVIRONMENT ?= dev
BACKUP_NAME ?= manual-$(shell date +%Y%m%d-%H%M%S)
PUPPET_ENV ?= production

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

init: ## Initialize the project
	cd terraform/environments/$(ENVIRONMENT) && terraform init
	cd puppet && bundle install
	cd puppet && bolt module install
	helm repo update

validate: ## Validate configurations
	cd terraform/environments/$(ENVIRONMENT) && terraform validate
	cd puppet && pdk validate
	cd puppet && bolt plan show
	kubectl --dry-run=client apply -k k8s/overlays/$(ENVIRONMENT)

puppet-deploy: ## Deploy using Puppet Bolt
	cd puppet && bolt plan run pi_cluster_automation::deploy \
		--inventoryfile ../inventory.yaml \
		environment=$(ENVIRONMENT) \
		--run-as root

puppet-test: ## Run Puppet tests
	cd puppet && pdk test unit
	cd puppet && pdk test unit --parallel

puppet-facts: ## Gather facts from all nodes
	bolt task run facts --targets all --inventoryfile inventory.yaml

puppet-apply: ## Apply Puppet configuration to specific nodes
	bolt apply puppet/manifests/site.pp \
		--targets $(TARGETS) \
		--inventoryfile inventory.yaml \
		--hiera-config puppet/hiera.yaml

plan: ## Plan infrastructure changes
	cd terraform/environments/$(ENVIRONMENT) && terraform plan -var-file=terraform.tfvars

apply: ## Apply infrastructure changes and run Puppet
	cd terraform/environments/$(ENVIRONMENT) && terraform apply -var-file=terraform.tfvars -auto-approve
	$(MAKE) puppet-deploy

destroy: ## Destroy infrastructure
	@echo "WARNING: This will destroy all infrastructure in $(ENVIRONMENT)"
	@read -p "Type 'destroy-$(ENVIRONMENT)' to confirm: " confirm && \
	if [ "$$confirm" = "destroy-$(ENVIRONMENT)" ]; then \
		cd terraform/environments/$(ENVIRONMENT) && terraform destroy -var-file=terraform.tfvars -auto-approve; \
	else \
		echo "Destruction cancelled"; \
	fi

test: ## Run all tests
	cd tests/terraform && go test -v ./...
	cd puppet && pdk test unit
	cd tests/integration && pytest -v

backup: ## Create a manual backup
	velero backup create $(BACKUP_NAME) --wait
	bolt task run pi_cluster_automation::backup_configs \
		--targets masters \
		--inventoryfile inventory.yaml

restore: ## Restore from backup
	bolt plan run pi_cluster_automation::restore \
		backup_name=$(BACKUP_NAME) \
		environment=$(ENVIRONMENT) \
		--inventoryfile inventory.yaml

monitor: ## Open monitoring dashboards
	@echo "Opening Grafana..."
	kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

puppet-console: ## Open Puppet console (if using PE)
	@echo "Opening Puppet Console..."
	@echo "https://puppet.$(CLUSTER_DOMAIN)"

node-shell: ## Get shell on a node
	bolt command run 'sudo -i' --targets $(TARGET) --inventoryfile inventory.yaml

cluster-status: ## Check cluster status
	bolt task run pi_cluster_automation::cluster_status \
		--targets masters \
		--inventoryfile inventory.yaml
```

## 7. Cross-Platform Node Configuration

### puppet/site-modules/profiles/manifests/base/windows.pp

```puppet
# Windows-specific base configuration
class profiles::base::windows {
  # Windows Update configuration
  class { 'windows_updates':
    ensure => 'enabled',
    day    => 'Sunday',
    time   => '03:00',
  }
  
  # Essential Windows packages via Chocolatey
  include chocolatey
  
  $windows_packages = [
    'git',
    'vscode',
    'powershell-core',
    'kubernetes-cli',
    'helm',
  ]
  
  package { $windows_packages:
    ensure   => present,
    provider => 'chocolatey',
  }
  
  # Configure Windows Defender exclusions
  windows_defender_exclusion { 'C:\k':
    ensure => present,
    type   => 'folder',
  }
}
```

### puppet/site-modules/profiles/manifests/base/darwin.pp

```puppet
# macOS-specific base configuration
class profiles::base::darwin {
  # Homebrew package management
  include homebrew
  
  $mac_packages = [
    'kubectl',
    'helm',
    'k9s',
    'stern',
    'jq',
    'yq',
  ]
  
  package { $mac_packages:
    ensure   => present,
    provider => 'homebrew',
  }
  
  # Configure macOS firewall
  exec { 'enable_firewall':
    command => '/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on',
    unless  => '/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate | grep "enabled"',
  }
}
```

## 8. Documentation Updates

### docs/puppet-guides/cross-platform-setup.md

```markdown
# Cross-Platform Setup Guide

## Overview
This guide covers setting up Puppet agents on different operating systems to manage your Pi cluster infrastructure.

## Supported Platforms
- Raspberry Pi OS (ARM)
- Ubuntu/Debian (x86_64)
- Windows Server 2019/2022
- macOS (for development)

## Installation

### Raspberry Pi / Linux
```bash
./scripts/setup/install-puppet-agent.sh puppet.cluster.local prod
```

### Windows
```powershell
.\scripts\setup\install-puppet-agent.ps1 -PuppetServer puppet.cluster.local -Environment prod
```

### macOS
```bash
brew install --cask puppet-agent
./scripts/setup/install-puppet-agent.sh puppet.cluster.local dev
```

## Verification
```bash
# Check Puppet agent status
sudo puppet agent --test

# View last run report
sudo puppet last_run_report print
```

## Bolt Usage

### Running commands across platforms
```bash
# Run on all nodes
bolt command run 'echo "Hello from $(hostname)"' --targets all

# Run on specific OS
bolt command run 'uname -a' --targets linux_nodes
bolt command run 'Get-ComputerInfo' --targets windows_nodes
```

### Applying configurations
```bash
# Apply a specific profile
bolt apply --execute 'include profiles::monitoring_agent' --targets workers
```

## Troubleshooting

### Certificate Issues
```bash
# Clean certificates
sudo puppet ssl clean $(hostname -f)

# Regenerate certificates
sudo puppet agent -t --waitforcert 60
```

### Connectivity Issues
```bash
# Test Puppet server connection
telnet puppet.cluster.local 8140

# Check Puppet configuration
puppet config print --section agent
```
```

## Benefits of Using Puppet

1. **True Cross-Platform Support**: Native support for Windows, macOS, and Linux
2. **Declarative Configuration**: Define desired state, Puppet handles implementation
3. **Puppet Forge**: Extensive module ecosystem for common tasks
4. **Bolt Orchestration**: Agentless task execution and plan orchestration
5. **Enterprise Features**: Optional Puppet Enterprise for GUI, RBAC, and compliance
6. **Hiera Data Management**: Separate configuration data from code
7. **Strong Testing Framework**: RSpec-puppet for comprehensive testing
8. **Mature Ecosystem**: Well-established tool with extensive documentation
9. **Reporting & Compliance**: Built-in reporting and compliance features
10. **Scale**: Efficiently manages thousands of nodes

This structure provides a production-ready, cross-platform Pi cluster infrastructure management solution using Puppet.