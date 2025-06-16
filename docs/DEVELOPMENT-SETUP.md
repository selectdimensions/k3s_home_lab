# Pi K3s Home Lab - Development Setup Guide

This guide will help you set up your development environment to work with the Pi K3s Home Lab project.

## Prerequisites

### Hardware Requirements
- 4x Raspberry Pi 5 (8GB RAM recommended)
- 4x High-quality microSD cards (64GB+ U3 class)
- Network switch with Gigabit Ethernet
- Proper cooling (fans or heatsinks)
- Reliable power supplies (USB-C 5V/5A)

### Network Setup
- Configure static IP addresses for all Pis:
  - Pi Master: 192.168.0.120
  - Pi Worker 1: 192.168.0.121
  - Pi Worker 2: 192.168.0.122
  - Pi Worker 3: 192.168.0.123
- Ensure SSH access is enabled
- Set up SSH key-based authentication

## Software Prerequisites

### On Your Development Machine

#### Windows
```powershell
# Install required tools using Chocolatey
choco install git terraform kubectl helm docker-desktop

# Install PowerShell 7+ if not already installed
choco install powershell-core

# Install Windows Subsystem for Linux (optional but recommended)
wsl --install
```

#### Linux/macOS
```bash
# Install Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt update && sudo apt install terraform

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl https://get.helm.sh/helm-v3.14.0-linux-amd64.tar.gz | tar xz
sudo mv linux-amd64/helm /usr/local/bin/

# Install Docker (Ubuntu/Debian)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

## Project Setup

### 1. Clone the Repository
```bash
git clone https://github.com/selectdimensions/k3s_home_lab.git
cd k3s_home_lab
```

### 2. Configure Your Environment

#### Copy Example Files
```bash
# Copy inventory template
cp inventory.yaml.example inventory.yaml

# Copy Terraform variables template
cp terraform/environments/prod/terraform.tfvars.example terraform/environments/prod/terraform.tfvars
```

#### Edit Configuration Files

**inventory.yaml**: Update with your actual Pi IP addresses
```yaml
version: 2
groups:
  - name: masters
    targets:
      - name: pi-master
        uri: 192.168.0.120  # Update with your master Pi IP
        vars:
          role: master
          hostname: pi-master
```

**terraform/environments/prod/terraform.tfvars**: Add secure passwords
```hcl
# Generate secure passwords
postgres_password = "$(openssl rand -base64 32)"
minio_secret_key = "$(openssl rand -base64 32)"
vault_token = "$(openssl rand -base64 32)"
nifi_admin_password = "$(openssl rand -base64 16)"
trino_admin_password = "$(openssl rand -base64 16)"
grafana_admin_password = "$(openssl rand -base64 16)"
```

### 3. Initialize the Project

#### Using Make (Linux/macOS)
```bash
make init
```

#### Using PowerShell (Windows)
```powershell
.\Make.ps1 init
```

### 4. Validate Configuration
```bash
# Linux/macOS
make validate

# Windows
.\Make.ps1 validate
```

## Development Workflow

### Daily Development Tasks

#### Check Project Status
```bash
# Linux/macOS
make cluster-status

# Windows
.\Make.ps1 cluster-status
```

#### Deploy Changes
```bash
# Plan changes first
make plan

# Apply changes
make apply

# Or do both at once
make quick-deploy
```

#### Monitor the Cluster
```bash
# Open monitoring dashboards
make monitor

# View logs
make logs
```

#### Backup Before Major Changes
```bash
# Create backup
make backup BACKUP_NAME=pre-major-change-$(date +%Y%m%d)
```

### Testing Changes

#### Validate Configuration
```bash
make validate
```

#### Run Tests
```bash
make test
```

#### Deploy to Development Environment
```bash
make apply ENVIRONMENT=dev
```

## Common Development Scenarios

### Adding a New Service

1. **Add Kubernetes manifests** in `k8s/base/` or `k8s/overlays/prod/`
2. **Add Helm values** in `k8s/helm-values/`
3. **Update Puppet configuration** in `puppet/site-modules/profiles/`
4. **Add Terraform resources** in `terraform/modules/`
5. **Test deployment**:
   ```bash
   make validate
   make plan
   make apply ENVIRONMENT=dev
   ```

### Modifying Cluster Configuration

1. **Update Puppet manifests** in `puppet/site-modules/`
2. **Test Puppet changes**:
   ```bash
   make puppet-deploy ENVIRONMENT=dev
   ```
3. **Validate and apply**:
   ```bash
   make validate
   make apply
   ```

### Updating Dependencies

```bash
# Update all dependencies
make update-deps

# Update specific components
cd terraform/environments/prod && terraform init -upgrade
cd puppet && bundle update
helm repo update
```

## Troubleshooting

### Common Issues

#### SSH Connection Problems
- Verify SSH keys are properly configured
- Check firewall settings on Pi nodes
- Ensure SSH service is running on all Pis

#### Terraform Issues
- Check AWS credentials if using remote backend
- Verify all required variables are set in `terraform.tfvars`
- Run `terraform init` if providers are outdated

#### Puppet Issues
- Ensure Puppet agent is installed on all nodes
- Check Puppet server connectivity
- Verify inventory.yaml syntax

#### Kubernetes Issues
- Check if K3s is running: `systemctl status k3s`
- Verify kubeconfig is properly configured
- Check cluster nodes: `kubectl get nodes`

### Getting Help

1. **Check logs**: `make logs`
2. **Validate configuration**: `make validate`
3. **Check cluster status**: `make cluster-status`
4. **Review documentation** in `docs/`
5. **Create an issue** on GitHub with:
   - Error messages
   - Steps to reproduce
   - Environment information

## Best Practices

### Security
- Use strong passwords generated with `openssl rand -base64 32`
- Keep secrets in `terraform.tfvars` and never commit them
- Regularly update dependencies
- Monitor security scan results in GitHub Actions

### Development
- Test in development environment first
- Use descriptive commit messages
- Create feature branches for major changes
- Run validation before committing
- Create backups before major changes

### Operations
- Monitor resource usage on Pi nodes
- Keep documentation updated
- Use semantic versioning for releases
- Regular backup and restore testing

## Next Steps

After setup is complete:

1. **Deploy the cluster**: `make quick-deploy`
2. **Access services**:
   - NiFi: http://192.168.0.120:30080
   - Grafana: http://192.168.0.120:30082
   - Trino: http://192.168.0.120:30081
3. **Explore the data platform** with example workflows
4. **Set up monitoring alerts** in Grafana
5. **Create your first data pipeline** in NiFi

## Additional Resources

- [Architecture Documentation](docs/architecture/)
- [Puppet Setup Guide](docs/puppet-guides/)
- [Runbooks](docs/runbooks/)
- [Windows Setup Guide](docs/WINDOWS-SETUP.md)
