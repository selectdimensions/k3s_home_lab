# Quick Fix for K3s Master Node Scheduling Issue
# Run these commands to fix the SchedulingDisabled issue

Write-Host "🚀 Quick K3s Fix - Enabling Master Node Scheduling" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green

# 1. Enable scheduling on master node (remove cordon)
Write-Host "`n1️⃣ Enabling scheduling on master node..." -ForegroundColor Cyan
& "$PSScriptRoot\bolt.ps1" -cmd "command run 'kubectl uncordon pi-master'" -targets "pi-master" -inventory "inventory.yaml"

# 2. Remove taints that prevent scheduling
Write-Host "`n2️⃣ Removing scheduling taints..." -ForegroundColor Cyan
& "$PSScriptRoot\bolt.ps1" -cmd "command run 'kubectl taint nodes pi-master node-role.kubernetes.io/control-plane:NoSchedule- || true'" -targets "pi-master" -inventory "inventory.yaml"
& "$PSScriptRoot\bolt.ps1" -cmd "command run 'kubectl taint nodes pi-master node-role.kubernetes.io/master:NoSchedule- || true'" -targets "pi-master" -inventory "inventory.yaml"

# 3. Delete pending pods so they can be rescheduled
Write-Host "`n3️⃣ Cleaning up pending pods..." -ForegroundColor Cyan
& "$PSScriptRoot\bolt.ps1" -cmd "command run 'kubectl delete pods --field-selector=status.phase=Pending -n kube-system'" -targets "pi-master" -inventory "inventory.yaml"

# 4. Wait and check status
Write-Host "`n⏳ Waiting 30 seconds for changes to take effect..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# 5. Check the result
Write-Host "`n5️⃣ Checking cluster status..." -ForegroundColor Cyan
& "$PSScriptRoot\bolt.ps1" -cmd "command run 'kubectl get nodes'" -targets "pi-master" -inventory "inventory.yaml"
& "$PSScriptRoot\bolt.ps1" -cmd "command run 'kubectl get pods -n kube-system'" -targets "pi-master" -inventory "inventory.yaml"

Write-Host "`n✅ Quick fix complete! Check the output above." -ForegroundColor Green
Write-Host "📝 Expected results:" -ForegroundColor Yellow
Write-Host "  - Master node should show 'Ready' (not SchedulingDisabled)" -ForegroundColor White
Write-Host "  - Pods should show 'Running' or 'ContainerCreating'" -ForegroundColor White
Write-Host "`n🔄 If pods are still pending, wait 2-3 minutes and run:" -ForegroundColor Cyan
Write-Host "    .\Make.ps1 cluster-status -Environment dev" -ForegroundColor White
