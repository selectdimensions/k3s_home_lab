<#
.SYNOPSIS
    K3s Master Node Upgrade Script - Fixes version skew issue

.DESCRIPTION
    Upgrades k3s master from v1.28.4 to v1.32.5 to match worker nodes
    and resolve version skew issue preventing worker pod scheduling.

.PARAMETER BackupFirst
    Perform full cluster backup before upgrade (default: true)

.PARAMETER TargetVersion
    Target k3s version (default: v1.32.5+k3s1)

.PARAMETER MasterIP
    Master node IP address (default: 192.168.0.120)

.PARAMETER SSHUser
    SSH username for master node (default: hezekiah)

.EXAMPLE
    .\Upgrade-K3sMaster.ps1 -BackupFirst $true
#>

param(
    [bool]$BackupFirst = $true,
    [string]$TargetVersion = "v1.32.5+k3s1",
    [string]$MasterIP = "192.168.0.120",
    [string]$SSHUser = "hezekiah"
)

# Colors for output
function Write-Step { param([string]$Message) Write-Host "`n▶ $Message" -ForegroundColor Cyan }
function Write-Success { param([string]$Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Warning { param([string]$Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param([string]$Message) Write-Host "❌ $Message" -ForegroundColor Red }

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║  K3s Master Upgrade: v1.28.4 → $TargetVersion" -ForegroundColor Blue
Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Blue

# Pre-flight checks
Write-Step "Pre-flight Checks"

Write-Host "Checking kubectl connectivity..."
$nodes = kubectl get nodes --no-headers 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Cannot connect to cluster. Ensure kubectl is configured."
    exit 1
}
Write-Success "Cluster accessible"

# Display current state
Write-Step "Current Cluster State"
kubectl get nodes -o wide

$masterVersion = (kubectl get node pi-master -o jsonpath='{.status.nodeInfo.kubeletVersion}')
$worker1Version = (kubectl get node pi-worker-1 -o jsonpath='{.status.nodeInfo.kubeletVersion}')

Write-Host "`nCurrent Versions:"
Write-Host "  Master:    $masterVersion" -ForegroundColor Yellow
Write-Host "  Worker-1:  $worker1Version" -ForegroundColor Yellow
Write-Host "  Target:    $TargetVersion" -ForegroundColor Green

if ($masterVersion -eq $TargetVersion) {
    Write-Success "Master is already at target version!"
    exit 0
}

# Backup phase
if ($BackupFirst) {
    Write-Step "Creating Backup"

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupDir = "backups\pre-upgrade-$timestamp"

    if (!(Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir | Out-Null
    }

    Write-Host "Backing up cluster state..."
    kubectl get all -A -o yaml > "$backupDir\all-resources.yaml"
    kubectl get pv,pvc -A -o yaml > "$backupDir\persistent-volumes.yaml"
    kubectl get configmap -A -o yaml > "$backupDir\configmaps.yaml"
    kubectl get secret -A -o yaml > "$backupDir\secrets.yaml"
    kubectl get nodes -o yaml > "$backupDir\nodes.yaml"

    Write-Success "Backup created in: $backupDir"

    # Display backup summary
    $backupFiles = Get-ChildItem $backupDir
    Write-Host "`nBackup Contents:"
    $backupFiles | ForEach-Object {
        $size = [math]::Round($_.Length / 1KB, 2)
        Write-Host "  $($_.Name): ${size}KB"
    }
}

# Confirmation
Write-Step "Ready to Upgrade"
Write-Warning "This will upgrade the master node from $masterVersion to $TargetVersion"
Write-Warning "Expected downtime: 2-5 minutes"
Write-Host ""
$confirm = Read-Host "Proceed with upgrade? (yes/no)"

if ($confirm -ne "yes") {
    Write-Host "Upgrade cancelled." -ForegroundColor Yellow
    exit 0
}

# Generate upgrade commands
Write-Step "Generating Upgrade Commands"

$upgradeScript = @"
#!/bin/bash
set -e

echo "==========================================="
echo "K3s Master Upgrade to $TargetVersion"
echo "==========================================="
echo ""

echo "▶ Stopping k3s service..."
sudo systemctl stop k3s
sleep 2

echo "▶ Downloading and installing k3s $TargetVersion..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$TargetVersion sh -s - server \
  --disable traefik \
  --disable servicelb \
  --write-kubeconfig-mode 644

echo ""
echo "▶ Restarting k3s service..."
sudo systemctl restart k3s
sleep 5

echo ""
echo "▶ Checking k3s status..."
sudo systemctl status k3s --no-pager -l

echo ""
echo "▶ Verifying version..."
k3s --version

echo ""
echo "==========================================="
echo "✅ Upgrade Complete!"
echo "==========================================="
"@

# Save script
$upgradeScript | Out-File -FilePath "upgrade-master.sh" -Encoding ASCII -NoNewline

Write-Success "Upgrade script created: upgrade-master.sh"

# SSH connection test
Write-Step "Testing SSH Connection"
Write-Host "Testing connection to ${SSHUser}@${MasterIP}..."

$sshTest = ssh -o ConnectTimeout=5 ${SSHUser}@${MasterIP} "echo connected" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "SSH connection failed. Please configure SSH access first."
    Write-Host "`nTo configure SSH:"
    Write-Host "  1. Copy your SSH key: ssh-copy-id ${SSHUser}@${MasterIP}"
    Write-Host "  2. Or use password: ssh ${SSHUser}@${MasterIP}"
    Write-Host "`nAlternatively, run the upgrade manually:"
    Write-Host "  1. Copy upgrade-master.sh to the master node"
    Write-Host "  2. SSH to master: ssh ${SSHUser}@${MasterIP}"
    Write-Host "  3. Run: bash upgrade-master.sh"
    exit 1
}
Write-Success "SSH connection OK"

# Execute upgrade
Write-Step "Executing Upgrade on Master Node"
Write-Warning "This will take 2-5 minutes..."

# Copy script to master
Write-Host "Copying upgrade script to master..."
scp upgrade-master.sh ${SSHUser}@${MasterIP}:/tmp/upgrade-master.sh

# Execute upgrade
Write-Host "Executing upgrade script..."
ssh ${SSHUser}@${MasterIP} "bash /tmp/upgrade-master.sh"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Upgrade failed! Check the output above for errors."
    exit 1
}

# Wait for cluster to stabilize
Write-Step "Waiting for Cluster to Stabilize"
Write-Host "Waiting 30 seconds for services to restart..."
Start-Sleep -Seconds 30

# Verify upgrade
Write-Step "Verifying Upgrade"

Write-Host "Checking node status..."
kubectl get nodes -o wide

$newMasterVersion = (kubectl get node pi-master -o jsonpath='{.status.nodeInfo.kubeletVersion}' 2>&1)
Write-Host "`nNew Master Version: $newMasterVersion"

if ($newMasterVersion -eq $TargetVersion) {
    Write-Success "Master successfully upgraded to $TargetVersion!"
} else {
    Write-Warning "Version mismatch detected. Expected: $TargetVersion, Got: $newMasterVersion"
}

# Check pod status
Write-Step "Checking Pod Status"
kubectl get pods -A -o wide

# Restart worker agents
Write-Step "Restarting Worker Agents"
Write-Host "This will help workers reconnect with the upgraded master..."

Write-Host "`nTo restart workers, run on each worker:"
Write-Host "  ssh ${SSHUser}@192.168.0.121 'sudo systemctl restart k3s-agent'"
Write-Host "  ssh ${SSHUser}@192.168.0.122 'sudo systemctl restart k3s-agent'"

$restartWorkers = Read-Host "`nAttempt to restart workers now? (yes/no)"
if ($restartWorkers -eq "yes") {
    Write-Host "Restarting pi-worker-1..."
    ssh ${SSHUser}@192.168.0.121 "sudo systemctl restart k3s-agent"

    Write-Host "Restarting pi-worker-2..."
    ssh ${SSHUser}@192.168.0.122 "sudo systemctl restart k3s-agent"

    Write-Host "Waiting 15 seconds for agents to reconnect..."
    Start-Sleep -Seconds 15
}

# Final validation
Write-Step "Final Validation"

Write-Host "Node versions:"
kubectl get nodes -o custom-columns=NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion

Write-Host "`nPod distribution:"
kubectl get pods -A -o wide | Select-String -Pattern "pi-worker" | Select-Object -First 10

# Check for version skew
$allVersions = kubectl get nodes -o jsonpath='{range .items[*]}{.status.nodeInfo.kubeletVersion}{"\n"}{end}' | Sort-Object -Unique
$versionCount = ($allVersions | Measure-Object).Count

if ($versionCount -eq 1) {
    Write-Success "All nodes running same version: $allVersions"
} else {
    Write-Warning "Multiple versions detected:"
    $allVersions | ForEach-Object { Write-Host "  $_" }
}

# Summary
Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              Upgrade Process Complete                        ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`nNext Steps:"
Write-Host "1. Monitor pod distribution: kubectl get pods -A -o wide"
Write-Host "2. Check cluster events: kubectl get events -A --sort-by='.lastTimestamp'"
Write-Host "3. Verify services: kubectl get svc -A"
Write-Host "4. Test application access (NiFi, Grafana, etc.)"
Write-Host "5. Run full validation: .\scripts\validate-infrastructure.ps1"

Write-Host "`nBackup Location: $backupDir" -ForegroundColor Cyan
Write-Host "Upgrade Script: upgrade-master.sh" -ForegroundColor Cyan

# Cleanup
Write-Host "`nCleanup upgrade script? (yes/no)"
$cleanup = Read-Host
if ($cleanup -eq "yes") {
    Remove-Item upgrade-master.sh -Force
    Write-Success "Cleanup complete"
}
