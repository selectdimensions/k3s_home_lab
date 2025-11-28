#!/usr/bin/env pwsh
# Fix K3s Worker Node Joining Issue
# This script manually joins worker nodes to the existing K3s cluster

param(
    [string]$MasterIP = "192.168.0.120",
    [string[]]$WorkerIPs = @("192.168.0.121", "192.168.0.122", "192.168.0.123"),
    [string]$Username = "hezekiah",
    [string]$SSHKeyPath = "$env:USERPROFILE\.ssh\keys\hobby\pi_k3s_cluster",
    [switch]$Force
)

Write-Host "🔧 K3s Worker Node Fix Script" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Master IP: $MasterIP" -ForegroundColor Green
Write-Host "Worker IPs: $($WorkerIPs -join ', ')" -ForegroundColor Green
Write-Host ""

# Function to run SSH command
function Invoke-SSHCommand {
    param(
        [string]$HostIP,
        [string]$Command,
        [string]$Description
    )

    Write-Host "📡 $Description on $HostIP..." -ForegroundColor Yellow

    if (Test-Path $SSHKeyPath) {
        $sshCmd = "ssh -i `"$SSHKeyPath`" -o StrictHostKeyChecking=no $Username@$HostIP `"$Command`""
        Write-Host "   Running: $Command" -ForegroundColor Gray

        try {
            $result = Invoke-Expression $sshCmd
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   ✅ Success" -ForegroundColor Green
                return $result
            } else {
                Write-Host "   ❌ Failed (exit code: $LASTEXITCODE)" -ForegroundColor Red
                return $null
            }
        } catch {
            Write-Host "   ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            return $null
        }
    } else {
        Write-Host "   ❌ SSH key not found: $SSHKeyPath" -ForegroundColor Red
        return $null
    }
}

# Step 1: Verify master node accessibility
Write-Host "🔍 Step 1: Verifying master node accessibility" -ForegroundColor Cyan
$masterTest = Invoke-SSHCommand -HostIP $MasterIP -Command "sudo systemctl status k3s" -Description "Testing master node K3s status"
if (-not $masterTest) {
    Write-Host "❌ Cannot access master node. Check SSH configuration." -ForegroundColor Red
    exit 1
}

# Step 2: Extract K3s token from master
Write-Host "🔑 Step 2: Extracting K3s token from master" -ForegroundColor Cyan
$k3sToken = Invoke-SSHCommand -HostIP $MasterIP -Command "sudo cat /var/lib/rancher/k3s/server/node-token" -Description "Getting K3s join token"
if (-not $k3sToken) {
    Write-Host "❌ Cannot retrieve K3s token from master" -ForegroundColor Red
    exit 1
}
$k3sToken = $k3sToken.Trim()
Write-Host "   Token: $($k3sToken.Substring(0,20))..." -ForegroundColor Green

# Step 3: Check current cluster nodes
Write-Host "📊 Step 3: Current cluster status" -ForegroundColor Cyan
Write-Host "Current nodes in cluster:" -ForegroundColor Yellow
kubectl get nodes -o wide

# Step 4: Join worker nodes
Write-Host "👥 Step 4: Joining worker nodes to cluster" -ForegroundColor Cyan

foreach ($workerIP in $WorkerIPs) {
    Write-Host "`n🔧 Processing worker node: $workerIP" -ForegroundColor Yellow

    # Check if K3s agent is already running
    $agentStatus = Invoke-SSHCommand -HostIP $workerIP -Command "sudo systemctl is-active k3s-agent" -Description "Checking K3s agent status"

    if ($agentStatus -eq "active" -and -not $Force) {
        Write-Host "   ℹ️  K3s agent already running. Use -Force to reinstall" -ForegroundColor Blue
        continue
    }

    # Stop existing K3s agent if running
    if ($agentStatus -eq "active") {
        Write-Host "   🛑 Stopping existing K3s agent" -ForegroundColor Yellow
        Invoke-SSHCommand -HostIP $workerIP -Command "sudo systemctl stop k3s-agent" -Description "Stopping K3s agent"
        Invoke-SSHCommand -HostIP $workerIP -Command "sudo systemctl disable k3s-agent" -Description "Disabling K3s agent"
    }

    # Install/reinstall K3s agent
    Write-Host "   📦 Installing K3s agent" -ForegroundColor Yellow
    $installCmd = "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.32.5+k3s1 K3S_URL=https://$MasterIP:6443 K3S_TOKEN=$k3sToken sh -s - agent --node-name `$(hostname) --node-ip $workerIP"

    $installResult = Invoke-SSHCommand -HostIP $workerIP -Command $installCmd -Description "Installing K3s agent"

    if ($installResult) {
        Write-Host "   ✅ K3s agent installed successfully" -ForegroundColor Green

        # Wait for agent to start
        Write-Host "   ⏳ Waiting for K3s agent to start..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10

        # Verify agent is running
        $finalStatus = Invoke-SSHCommand -HostIP $workerIP -Command "sudo systemctl is-active k3s-agent" -Description "Verifying K3s agent status"
        if ($finalStatus -eq "active") {
            Write-Host "   ✅ K3s agent is now active" -ForegroundColor Green
        } else {
            Write-Host "   ❌ K3s agent failed to start" -ForegroundColor Red
        }
    } else {
        Write-Host "   ❌ K3s agent installation failed" -ForegroundColor Red
    }
}

# Step 5: Final verification
Write-Host "`n✅ Step 5: Final cluster verification" -ForegroundColor Cyan
Write-Host "Waiting 30 seconds for nodes to join..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host "`nFinal cluster status:" -ForegroundColor Yellow
kubectl get nodes -o wide

Write-Host "`nPod distribution:" -ForegroundColor Yellow
kubectl get pods -A -o wide

Write-Host "`n🎉 Worker node fix script completed!" -ForegroundColor Green
Write-Host "If nodes still show as NotReady, wait a few more minutes for them to fully initialize." -ForegroundColor Blue
