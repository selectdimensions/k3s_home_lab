# K3s Cluster Troubleshooting Script
# Fixes common issues with master node scheduling and pending pods

Write-Host "🔍 K3s Cluster Troubleshooting Started" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

# Function to execute commands on the master node
function Invoke-MasterCommand {
    param([string]$Command, [string]$Description)

    Write-Host "➡️ $Description..." -ForegroundColor Cyan
    & "$PSScriptRoot\bolt.ps1" -cmd "command run '$Command'" -targets "pi-master" -inventory "inventory.yaml"
}

# Function to check and fix node scheduling
function Fix-NodeScheduling {
    Write-Host "🔧 Checking and fixing node scheduling..." -ForegroundColor Yellow

    # Check if master node allows scheduling
    Invoke-MasterCommand "kubectl get nodes -o wide" "Getting current node status"

    # Remove scheduling taint from master node (allows pods to run on master)
    Invoke-MasterCommand "kubectl taint nodes pi-master node-role.kubernetes.io/control-plane:NoSchedule- || true" "Removing control-plane taint"
    Invoke-MasterCommand "kubectl taint nodes pi-master node-role.kubernetes.io/master:NoSchedule- || true" "Removing master taint"

    # Enable scheduling on master node
    Invoke-MasterCommand "kubectl uncordon pi-master" "Enabling scheduling on master node"

    # Check node status after changes
    Invoke-MasterCommand "kubectl get nodes -o wide" "Verifying node status"
}

# Function to restart K3s components
function Restart-K3sComponents {
    Write-Host "🔄 Restarting K3s components..." -ForegroundColor Yellow

    # Restart K3s service
    Invoke-MasterCommand "systemctl restart k3s" "Restarting K3s service"

    # Wait for service to stabilize
    Start-Sleep -Seconds 30

    # Check service status
    Invoke-MasterCommand "systemctl status k3s --no-pager -l" "Checking K3s service status"
}

# Function to clean up and restart problematic pods
function Fix-PendingPods {
    Write-Host "🐳 Fixing pending pods..." -ForegroundColor Yellow

    # Delete pending pods to allow recreation
    Invoke-MasterCommand "kubectl delete pods --field-selector=status.phase=Pending -n kube-system" "Deleting pending pods"

    # Wait for pods to be recreated
    Start-Sleep -Seconds 15

    # Check pod status
    Invoke-MasterCommand "kubectl get pods -n kube-system -o wide" "Checking system pods status"
}

# Function to check cluster resources
function Check-ClusterResources {
    Write-Host "📊 Checking cluster resources..." -ForegroundColor Yellow

    # Check node capacity and allocatable resources
    Invoke-MasterCommand "kubectl describe node pi-master" "Getting detailed node information"

    # Check for resource constraints
    Invoke-MasterCommand "kubectl top node pi-master || echo 'Metrics server not ready yet'" "Checking node resource usage"
}

# Function to verify core services
function Verify-CoreServices {
    Write-Host "✅ Verifying core services..." -ForegroundColor Yellow

    # Check coredns
    Invoke-MasterCommand "kubectl get deployment coredns -n kube-system" "Checking CoreDNS deployment"

    # Check local-path-provisioner
    Invoke-MasterCommand "kubectl get deployment local-path-provisioner -n kube-system" "Checking local-path-provisioner"

    # Check metrics server
    Invoke-MasterCommand "kubectl get deployment metrics-server -n kube-system" "Checking metrics server"
}

# Function to apply comprehensive fixes
function Apply-ComprehensiveFix {
    Write-Host "🛠️ Applying comprehensive fixes..." -ForegroundColor Green

    # Step 1: Fix node scheduling
    Fix-NodeScheduling

    # Step 2: Clean up and restart K3s if needed
    Write-Host "`n⏳ Waiting for changes to take effect..." -ForegroundColor Cyan
    Start-Sleep -Seconds 20

    # Step 3: Fix pending pods
    Fix-PendingPods

    # Step 4: Wait and check again
    Write-Host "`n⏳ Waiting for pods to stabilize..." -ForegroundColor Cyan
    Start-Sleep -Seconds 30

    # Step 5: Verify everything is working
    Verify-CoreServices
}

# Main execution
try {
    Write-Host "`n🎯 Step 1: Initial Cluster Assessment" -ForegroundColor Magenta
    Invoke-MasterCommand "kubectl get nodes,pods -A" "Getting current cluster state"

    Write-Host "`n🎯 Step 2: Applying Fixes" -ForegroundColor Magenta
    Apply-ComprehensiveFix

    Write-Host "`n🎯 Step 3: Final Verification" -ForegroundColor Magenta
    Start-Sleep -Seconds 10
    Invoke-MasterCommand "kubectl get nodes,pods -A" "Final cluster state check"

    Write-Host "`n✅ Troubleshooting Complete!" -ForegroundColor Green
    Write-Host "🔍 Key things to verify:" -ForegroundColor Yellow
    Write-Host "  1. Master node should show 'Ready' status (not SchedulingDisabled)" -ForegroundColor White
    Write-Host "  2. System pods should be 'Running' or 'ContainerCreating' (not Pending)" -ForegroundColor White
    Write-Host "  3. If pods are still pending, run this script again after 2-3 minutes" -ForegroundColor White

    Write-Host "`n🚀 Next Steps:" -ForegroundColor Cyan
    Write-Host "  Run: .\Make.ps1 cluster-status -Environment dev" -ForegroundColor White
    Write-Host "  Or: .\Make.ps1 cluster-overview -Environment dev" -ForegroundColor White

} catch {
    Write-Error "❌ Troubleshooting failed: $_"
    Write-Host "`n🔧 Manual recovery steps:" -ForegroundColor Yellow
    Write-Host "1. SSH to master: ssh hezekiah@192.168.0.120" -ForegroundColor White
    Write-Host "2. Check K3s logs: sudo journalctl -u k3s -f" -ForegroundColor White
    Write-Host "3. Restart K3s: sudo systemctl restart k3s" -ForegroundColor White
    Write-Host "4. Check node: kubectl get nodes" -ForegroundColor White
}
