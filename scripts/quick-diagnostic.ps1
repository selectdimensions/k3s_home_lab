#!/usr/bin/env pwsh
# Quick Cluster Diagnostic Script
param(
    [switch]$ShowNodes,
    [switch]$ShowPods,
    [switch]$ShowServices,
    [switch]$ShowEvents,
    [switch]$All
)

if ($All) {
    $ShowNodes = $ShowPods = $ShowServices = $ShowEvents = $true
}

Write-Host "🔍 K3s Cluster Diagnostic Report" -ForegroundColor Cyan
Write-Host "Generated: $(Get-Date)" -ForegroundColor Gray
Write-Host "=" * 50

if ($ShowNodes -or $All) {
    Write-Host "`n📊 CLUSTER NODES" -ForegroundColor Yellow
    try {
        kubectl get nodes -o wide
        if ($LASTEXITCODE -ne 0) { throw "kubectl failed" }
    } catch {
        Write-Host "❌ Cannot get nodes. Is kubectl configured?" -ForegroundColor Red
    }
}

if ($ShowPods -or $All) {
    Write-Host "`n🚀 RUNNING PODS" -ForegroundColor Yellow
    try {
        kubectl get pods -A -o wide | Sort-Object
    } catch {
        Write-Host "❌ Cannot get pods" -ForegroundColor Red
    }
}

if ($ShowServices -or $All) {
    Write-Host "`n🌐 CLUSTER SERVICES" -ForegroundColor Yellow
    try {
        kubectl get services -A
    } catch {
        Write-Host "❌ Cannot get services" -ForegroundColor Red
    }
}

if ($ShowEvents -or $All) {
    Write-Host "`n📝 RECENT EVENTS" -ForegroundColor Yellow
    try {
        kubectl get events --sort-by=.metadata.creationTimestamp -A | Select-Object -Last 15
    } catch {
        Write-Host "❌ Cannot get events" -ForegroundColor Red
    }
}

Write-Host "`n🎯 QUICK CHECKS" -ForegroundColor Yellow
Write-Host "Worker Nodes Ready: " -NoNewline
$workers = kubectl get nodes --no-headers | Where-Object { $_ -notmatch "master" -and $_ -match "Ready" }
if ($workers) {
    Write-Host "$($workers.Count) workers ready" -ForegroundColor Green
} else {
    Write-Host "No workers ready" -ForegroundColor Red
}

Write-Host "System Pods Running: " -NoNewline
$systemPods = kubectl get pods -n kube-system --no-headers | Where-Object { $_ -match "Running" }
Write-Host "$($systemPods.Count) running" -ForegroundColor Green

Write-Host "`n💡 Next Actions:" -ForegroundColor Cyan
Write-Host "  1. Run worker deployment: .\Make.ps1 puppet-deploy -Targets workers" -ForegroundColor Gray
Write-Host "  2. Fix DNS if needed: .\scripts\cluster-fix.ps1 -FixDNS" -ForegroundColor Gray
Write-Host "  3. Rebalance workloads: .\scripts\cluster-fix.ps1 -RebalanceWorkloads" -ForegroundColor Gray
