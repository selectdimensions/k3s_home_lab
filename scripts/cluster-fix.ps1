#!/usr/bin/env pwsh
# DNS Configuration Fix and Cluster Rebalancing Script
# This script addresses DNS warnings and rebalances workloads across nodes

[CmdletBinding()]
param(
    [switch]$FixDNS,
    [switch]$RebalanceWorkloads,
    [switch]$All,
    [string]$DNSServers = "192.168.0.1,8.8.8.8"
)

function Write-Step {
    param([string]$Message)
    Write-Host "🔧 $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️ $Message" -ForegroundColor Yellow
}

function Fix-CoreDNSConfiguration {
    Write-Step "Fixing CoreDNS Configuration"

    # Get current CoreDNS config
    $currentConfig = kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' 2>$null

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Could not retrieve CoreDNS config. Is kubectl configured?"
        return
    }

    # Parse DNS servers
    $dnsArray = $DNSServers -split ","

    Write-Step "Updating CoreDNS to use DNS servers: $DNSServers"

    # Create a new CoreDNS configuration
    $newConfig = @"
.:53 {
    errors
    health {
       lameduck 5s
    }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
       ttl 30
    }
    prometheus :9153
    forward . $($dnsArray -join " ") {
       max_concurrent 1000
    }
    cache 30
    loop
    reload
    loadbalance
}
"@

    # Apply the new configuration
    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        $newConfig | Out-File -FilePath $tempFile -Encoding UTF8

        kubectl create configmap coredns-new --from-file=Corefile=$tempFile -n kube-system --dry-run=client -o yaml | kubectl apply -f -

        if ($LASTEXITCODE -eq 0) {
            # Replace the current config
            kubectl patch configmap coredns -n kube-system --patch='{"data":{"Corefile":".:53 {\n    errors\n    health {\n       lameduck 5s\n    }\n    ready\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\n       pods insecure\n       fallthrough in-addr.arpa ip6.arpa\n       ttl 30\n    }\n    prometheus :9153\n    forward . '$($dnsArray -join " ")' {\n       max_concurrent 1000\n    }\n    cache 30\n    loop\n    reload\n    loadbalance\n}"}}'

            if ($LASTEXITCODE -eq 0) {
                Write-Success "CoreDNS configuration updated successfully"

                # Restart CoreDNS pods
                Write-Step "Restarting CoreDNS pods"
                kubectl rollout restart deployment coredns -n kube-system

                if ($LASTEXITCODE -eq 0) {
                    Write-Success "CoreDNS pods restarted"

                    # Wait for rollout to complete
                    Write-Step "Waiting for CoreDNS rollout to complete..."
                    kubectl rollout status deployment coredns -n kube-system --timeout=120s

                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "CoreDNS rollout completed successfully"
                    } else {
                        Write-Warning "CoreDNS rollout may have timed out. Check manually with: kubectl get pods -n kube-system"
                    }
                } else {
                    Write-Warning "Failed to restart CoreDNS pods"
                }
            } else {
                Write-Warning "Failed to update CoreDNS configuration"
            }
        } else {
            Write-Warning "Failed to create new CoreDNS configuration"
        }
    } finally {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
}

function Rebalance-Workloads {
    Write-Step "Rebalancing Workloads Across Cluster"

    # Check current node status
    Write-Step "Checking current node status"
    kubectl get nodes -o wide

    # Get current pod distribution
    Write-Step "Current pod distribution:"
    kubectl get pods -A -o wide --sort-by='.spec.nodeName' | Format-Table -AutoSize

    # Check if we have worker nodes ready
    $workerNodes = kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name,ROLES:.metadata.labels.node-role\.kubernetes\.io/master | Where-Object { $_ -notmatch "master" -and $_ -notmatch "<none>" }

    if ($workerNodes.Count -eq 0) {
        Write-Warning "No worker nodes detected. Skipping workload rebalancing."
        Write-Step "Make sure worker nodes are properly joined to the cluster first."
        return
    }

    Write-Success "Found $($workerNodes.Count) worker nodes. Proceeding with rebalancing."

    # Drain master node of non-system pods (carefully)
    Write-Step "Draining master node of non-system workloads"

    # Get the master node name
    $masterNode = kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name,ROLES:.metadata.labels.node-role\.kubernetes\.io/master | Where-Object { $_ -match "master" } | ForEach-Object { ($_ -split '\s+')[0] } | Select-Object -First 1

    if ($masterNode) {
        Write-Step "Draining node: $masterNode"

        # Cordon the node first
        kubectl cordon $masterNode

        # Drain with specific options for safety
        kubectl drain $masterNode --ignore-daemonsets --delete-emptydir-data --force --grace-period=30 --timeout=300s

        if ($LASTEXITCODE -eq 0) {
            Write-Success "Master node drained successfully"

            # Wait a moment for pods to reschedule
            Write-Step "Waiting for pods to reschedule..."
            Start-Sleep -Seconds 30

            # Show new pod distribution
            Write-Step "New pod distribution after draining:"
            kubectl get pods -A -o wide --sort-by='.spec.nodeName' | Format-Table -AutoSize

            # Uncordon the master (allow scheduling but with taints)
            Write-Step "Uncordoning master node (will remain tainted for system workloads)"
            kubectl uncordon $masterNode

            Write-Success "Workload rebalancing completed"
        } else {
            Write-Warning "Failed to drain master node. Some pods may be stuck."
            Write-Step "You may need to manually delete stuck pods or check for PodDisruptionBudgets"
        }
    } else {
        Write-Warning "Could not identify master node"
    }
}

function Show-ClusterStatus {
    Write-Step "Current Cluster Status"

    Write-Host "`n=== NODES ===" -ForegroundColor Yellow
    kubectl get nodes -o wide

    Write-Host "`n=== PODS BY NODE ===" -ForegroundColor Yellow
    kubectl get pods -A -o wide --sort-by='.spec.nodeName' | Format-Table -AutoSize

    Write-Host "`n=== CLUSTER RESOURCES ===" -ForegroundColor Yellow
    kubectl top nodes 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Metrics server not available for resource usage"
    }

    Write-Host "`n=== SERVICES ===" -ForegroundColor Yellow
    kubectl get services -A | Format-Table -AutoSize

    Write-Host "`n=== RECENT EVENTS ===" -ForegroundColor Yellow
    kubectl get events --sort-by=.metadata.creationTimestamp | Select-Object -Last 10
}

# Main execution
Write-Step "DNS and Cluster Rebalancing Tool"

if ($All) {
    $FixDNS = $true
    $RebalanceWorkloads = $true
}

if ($FixDNS) {
    Fix-CoreDNSConfiguration
}

if ($RebalanceWorkloads) {
    Rebalance-Workloads
}

if ($FixDNS -or $RebalanceWorkloads -or $All) {
    Write-Step "Final cluster status:"
    Show-ClusterStatus

    Write-Success "DNS and rebalancing operations completed!"
    Write-Step "Next steps:"
    Write-Host "  1. Monitor cluster events: kubectl get events --watch" -ForegroundColor Cyan
    Write-Host "  2. Check pod distribution: kubectl get pods -A -o wide" -ForegroundColor Cyan
    Write-Host "  3. Verify DNS resolution: kubectl run -i --tty --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default" -ForegroundColor Cyan
} else {
    Write-Step "Available options:"
    Write-Host "  -FixDNS              : Fix CoreDNS configuration to reduce nameservers" -ForegroundColor Cyan
    Write-Host "  -RebalanceWorkloads  : Drain master and rebalance workloads to workers" -ForegroundColor Cyan
    Write-Host "  -All                 : Run both DNS fix and workload rebalancing" -ForegroundColor Cyan
    Write-Host "  -DNSServers          : Specify DNS servers (default: 192.168.0.1,8.8.8.8)" -ForegroundColor Cyan
    Write-Host "`nExample: .\cluster-fix.ps1 -All" -ForegroundColor Yellow
}
