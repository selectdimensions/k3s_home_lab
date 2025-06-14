# Getting Started with k3s_home_lab on Windows

This guide will help you set up and run the k3s_home_lab project on Windows.

## Overview

The k3s_home_lab project creates a production-grade Kubernetes cluster on Raspberry Pi hardware, managed with Puppet and Terraform. This guide provides Windows-specific instructions for managing the cluster.

## Prerequisites

### Hardware Requirements
- 4x Raspberry Pi 5 (8GB RAM recommended)
- MicroSD cards (64GB+ U3 class)
- Ethernet cables and switch
- Power supplies for each Pi

### Network Setup
- Static IP addresses for Pi nodes:
  - 192.168.0.120 - Pi Master (Puppet Server + K3s Master)
  - 192.168.0.121 - Pi Worker 1
  - 192.168.0.122 - Pi Worker 2 
  - 192.168.0.123 - Pi Worker 3

### Software Prerequisites on Windows
- Windows 10/11 with PowerShell 5.1+
- Administrator privileges (for some setup steps)
- Internet connection

## Step 1: Initial Windows Setup

Run the Windows setup script to install required tools:

```powershell
# Clone the repository (if not already done)
git clone https://github.com/your-username/k3s_home_lab.git
cd k3s_home_lab

# Run the Windows setup script as Administrator
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\scripts\setup\setup-windows.ps1
```

This script will:
- Install Chocolatey package manager
- Install Puppet Bolt, Terraform, Helm, Git, OpenSSH, and other tools
- Generate SSH keys for cluster access
- Update inventory.yaml for Windows paths
- Add cluster DNS entries to Windows hosts file
- Test connectivity to Pi nodes

## Step 2: Prepare Raspberry Pi Nodes

### Option A: Manual Pi Setup

1. Flash Raspberry Pi OS 64-bit to SD cards
2. Enable SSH by creating empty `ssh` file in boot partition
3. Insert SD cards and boot each Pi
4. Find Pi IP addresses and SSH to each:

```bash
# On each Pi, create user and enable SSH keys
sudo adduser hezekiah
sudo usermod -aG sudo hezekiah
sudo mkdir -p /home/hezekiah/.ssh
sudo chown hezekiah:hezekiah /home/hezekiah/.ssh
sudo chmod 700 /home/hezekiah/.ssh

# Add your public key (copy from Windows)
echo "your-ssh-public-key-here" | sudo tee /home/hezekiah/.ssh/authorized_keys
sudo chown hezekiah:hezekiah /home/hezekiah/.ssh/authorized_keys
sudo chmod 600 /home/hezekiah/.ssh/authorized_keys

# Enable cgroups for K3s
echo ' cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1' | sudo tee -a /boot/cmdline.txt
sudo reboot
```

### Option B: Automated Pi Setup (Recommended)

Use the PowerShell script to automate Pi preparation:

```powershell
# Prepare all Pi nodes automatically
.\scripts\setup\prepare-pis.ps1 -PiAddresses @("192.168.0.120", "192.168.0.121", "192.168.0.122", "192.168.0.123") -Username "hezekiah"
```

This script will:
- Copy SSH keys to each Pi
- Create the user account
- Install essential packages
- Configure cgroups for K3s
- Set hostnames
- Configure SSH security

## Step 3: Initialize the Project

```powershell
# Initialize Terraform, Puppet modules, and Helm repos
.\Make.ps1 init
```

## Step 4: Configure Your Environment

1. **Update inventory.yaml**: Verify the IP addresses and settings match your network
2. **Review configuration**: Check `puppet/data/common.yaml` for default settings
3. **Set up Terraform variables**:

```powershell
# Create terraform.tfvars in terraform/environments/dev/
cd terraform/environments/dev
Copy-Item terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your settings
notepad terraform.tfvars
```

## Step 5: Deploy the Cluster

### Validate Configuration First
```powershell
# Validate all configurations
.\Make.ps1 validate
```

### Deploy Infrastructure
```powershell
# Plan the deployment
.\Make.ps1 plan

# Apply the infrastructure
.\Make.ps1 apply
```

### Alternative: Puppet-only Deployment
```powershell
# Deploy using Puppet Bolt only
.\Make.ps1 puppet-deploy
```

## Step 6: Verify Deployment

```powershell
# Get kubeconfig from cluster
.\Make.ps1 kubeconfig

# Check cluster status
kubectl get nodes
kubectl get pods -A

# Check cluster health
.\Make.ps1 cluster-status
```

Expected output:
```
NAME        STATUS   ROLES                  AGE   VERSION
pi-master   Ready    control-plane,master   10m   v1.28.4+k3s1
pi-worker-1 Ready    <none>                 8m    v1.28.4+k3s1
pi-worker-2 Ready    <none>                 8m    v1.28.4+k3s1
pi-worker-3 Ready    <none>                 8m    v1.28.4+k3s1
```

## Step 7: Access Services

### NiFi Data Pipeline
```powershell
# Forward NiFi UI to local machine
.\Make.ps1 nifi-ui
# Browse to http://localhost:8080
```

### Grafana Monitoring
```powershell
# Forward Grafana UI to local machine
.\Make.ps1 grafana-ui
# Browse to http://localhost:3000
```

### Direct Service Access
Services are also available directly via their cluster IPs:
- NiFi: http://192.168.0.200:8080 (via MetalLB)
- Grafana: http://192.168.0.201:3000 (via MetalLB)

## Common Commands

```powershell
# Show all available commands
.\Make.ps1 help

# Check cluster status
.\Make.ps1 cluster-status

# Get shell on specific node
.\Make.ps1 node-shell -Targets pi-master

# Run Puppet facts collection
.\Make.ps1 puppet-facts

# Create backup
.\Make.ps1 backup -BackupName "before-upgrade"

# Restore from backup
.\Make.ps1 restore -BackupName "before-upgrade"

# Update configurations
.\Make.ps1 puppet-apply -Targets workers

# Destroy infrastructure (be careful!)
.\Make.ps1 destroy
```

## Troubleshooting

### Common Issues

1. **SSH Connection Failures**
   ```powershell
   # Test SSH connectivity
   ssh -i $env:USERPROFILE\.ssh\keys\hobby\pi_k3s_cluster hezekiah@192.168.0.120
   
   # Check SSH agent
   ssh-add $env:USERPROFILE\.ssh\keys\hobby\pi_k3s_cluster
   ```

2. **Puppet Certificate Issues**
   ```powershell
   # Clean and regenerate certificates
   bolt command run 'sudo puppet ssl clean $(hostname -f)' --targets all -i inventory.yaml
   bolt command run 'sudo puppet agent -t --waitforcert 60' --targets all -i inventory.yaml
   ```

3. **K3s Node Issues**
   ```powershell
   # Check K3s status on nodes
   bolt command run 'sudo systemctl status k3s' --targets masters -i inventory.yaml
   bolt command run 'sudo systemctl status k3s-agent' --targets workers -i inventory.yaml
   
   # View K3s logs
   bolt command run 'sudo journalctl -u k3s -f' --targets masters -i inventory.yaml
   ```

4. **Network Connectivity**
   ```powershell
   # Test cluster network
   kubectl get pods -n kube-system
   kubectl get svc -A
   
   # Check MetalLB
   kubectl get configmap -n metallb-system
   ```

### Log Locations

- **Puppet logs**: Check via `bolt command run 'sudo journalctl -u puppet' --targets all -i inventory.yaml`
- **K3s logs**: Check via `bolt command run 'sudo journalctl -u k3s' --targets masters -i inventory.yaml`
- **Application logs**: Use `kubectl logs <pod-name> -n <namespace>`

### Getting Help

1. Check the main README.md for detailed architecture information
2. Review Puppet manifests in `puppet/site-modules/profiles/manifests/`
3. Check Terraform modules in `terraform/modules/`
4. View runbooks in `docs/runbooks/`

## Data Engineering Workflows

Once the cluster is running, you can:

1. **Create NiFi Data Flows**
   - Access NiFi UI at http://localhost:8080 (after port forwarding)
   - Build data pipelines for ingesting and processing data
   - Connect to PostgreSQL and MinIO storage

2. **Query Data with Trino**
   ```powershell
   # Connect to Trino coordinator
   kubectl exec -it trino-coordinator-0 -n data-platform -- trino
   
   # Example queries
   SHOW CATALOGS;
   SHOW SCHEMAS FROM hive;
   SELECT * FROM hive.default.my_table LIMIT 10;
   ```

3. **Use JupyterLab for Analysis**
   ```powershell
   # Port forward to JupyterLab
   kubectl port-forward -n data-platform svc/jupyterlab 8888:8888
   # Browse to http://localhost:8888
   ```

4. **Monitor with Grafana**
   ```powershell
   # View cluster and application metrics
   .\Make.ps1 grafana-ui
   # Browse to http://localhost:3000
   ```

## Next Steps

- Explore the data platform components (NiFi, Trino, PostgreSQL, MinIO)
- Set up your own data pipelines
- Configure monitoring and alerting
- Implement backup strategies
- Scale the cluster by adding more Pi nodes

For more detailed information, see the comprehensive documentation in the main README.md file.
