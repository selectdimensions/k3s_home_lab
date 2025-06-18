#!/usr/bin/env pwsh
# Enhanced Puppet Deployment Script with APT Lock Prevention

[CmdletBinding()]
param(
    [string]$Environment = "prod",
    [string]$Targets = "all",
    [string]$Plan = "deploy_robust",
    [switch]$SkipPreFlight,
    [switch]$ForceAptFix,
    [int]$MaxRetries = 3
)

function Write-Step {
    param([string]$Message)
    Write-Host "🚀 $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Cyan
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Test-Prerequisites {
    Write-Step "Running pre-flight checks..."

    # Check if bolt command is available
    try {
        & "$PSScriptRoot\..\bolt.ps1" -cmd "command run 'echo test'" -targets "pi-master" -inventory "inventory.yaml" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Bolt connectivity test failed"
        }
    } catch {
        Write-Error "Cannot connect to cluster nodes. Check network connectivity and SSH keys."
        return $false
    }

    # Check if inventory file exists
    if (-not (Test-Path "$PSScriptRoot\..\inventory.yaml")) {
        Write-Error "Inventory file not found: inventory.yaml"
        return $false
    }

    Write-Info "✅ Prerequisites check passed"
    return $true
}

function Stop-SystemAPTProcesses {
    param([string]$NodeTargets)

    Write-Step "Stopping system APT processes on: $NodeTargets"

    $systemStopCommands = @(
        "sudo systemctl stop apt-daily.service || true",
        "sudo systemctl stop apt-daily.timer || true",
        "sudo systemctl stop apt-daily-upgrade.service || true",
        "sudo systemctl stop apt-daily-upgrade.timer || true",
        "sudo systemctl stop snapd.service || true",
        "sudo systemctl stop packagekit.service || true"
    )

    foreach ($cmd in $systemStopCommands) {
        Write-Info "Running: $cmd"
        & "$PSScriptRoot\..\bolt.ps1" -cmd "command run '$cmd'" -targets $NodeTargets -inventory "inventory.yaml"
        Start-Sleep -Seconds 2
    }

    # Wait for processes to stop
    Write-Info "Waiting for services to stop..."
    Start-Sleep -Seconds 10
}

function Clear-APTLocks {
    param([string]$NodeTargets)

    Write-Step "Clearing APT locks on: $NodeTargets"

    $lockClearCommands = @(
        "sudo pkill -f apt || true",
        "sudo pkill -f dpkg || true",
        "sudo pkill -f unattended-upgrade || true",
        "sudo rm -f /var/lib/apt/lists/lock || true",
        "sudo rm -f /var/cache/apt/archives/lock || true",
        "sudo rm -f /var/lib/dpkg/lock* || true",
        "sudo rm -f /var/lib/apt/daily_lock || true"
    )

    foreach ($cmd in $lockClearCommands) {
        Write-Info "Running: $cmd"
        & "$PSScriptRoot\..\bolt.ps1" -cmd "command run '$cmd'" -targets $NodeTargets -inventory "inventory.yaml"
    }

    # Configure APT to prevent automatic processes during deployment
    Write-Info "Configuring APT for deployment mode..."
    & "$PSScriptRoot\..\bolt.ps1" -cmd "command run 'echo \"APT::Periodic::Enable \\\"0\\\";\" | sudo tee /etc/apt/apt.conf.d/99disable-periodic'" -targets $NodeTargets -inventory "inventory.yaml"

    Start-Sleep -Seconds 3
}

function Restore-APTConfiguration {
    param([string]$NodeTargets)

    Write-Step "Restoring APT automatic processes on: $NodeTargets"

    $restoreCommands = @(
        "sudo rm -f /etc/apt/apt.conf.d/99disable-periodic || true",
        "sudo systemctl start apt-daily.timer || true",
        "sudo systemctl start apt-daily-upgrade.timer || true"
    )

    foreach ($cmd in $restoreCommands) {
        Write-Info "Running: $cmd"
        & "$PSScriptRoot\..\bolt.ps1" -cmd "command run '$cmd'" -targets $NodeTargets -inventory "inventory.yaml"
    }
}

function Invoke-PuppetDeployment {
    param([string]$PlanName, [string]$NodeTargets, [string]$Env)

    Write-Step "Executing Puppet plan: $PlanName"
    Write-Info "Targets: $NodeTargets"
    Write-Info "Environment: $Env"

    $planParams = @{
        environment = $Env
        targets = $NodeTargets
        force_apt_fix = $true
        timeout = 1800
    }

    $paramsJson = $planParams | ConvertTo-Json -Compress
    $boltCommand = "plan run pi_cluster::$PlanName --params '$paramsJson'"

    Write-Info "Executing: $boltCommand"
    & "$PSScriptRoot\..\bolt.ps1" -cmd $boltCommand -targets $NodeTargets -inventory "inventory.yaml"

    return $LASTEXITCODE -eq 0
}

function Test-DeploymentResult {
    Write-Step "Validating deployment result..."

    # Check K3s cluster status
    Write-Info "Checking K3s cluster status..."
    & "$PSScriptRoot\..\bolt.ps1" -cmd "task run cluster_status" -targets "pi-master" -inventory "inventory.yaml"

    if ($LASTEXITCODE -eq 0) {
        Write-Info "✅ Cluster status check passed"
        return $true
    } else {
        Write-Warning "⚠️  Cluster status check failed or incomplete"
        return $false
    }
}

# Main execution flow
Write-Step "🚀 Enhanced Puppet Deployment Script"
Write-Info "Environment: $Environment"
Write-Info "Targets: $Targets"
Write-Info "Plan: $Plan"
Write-Info "Max Retries: $MaxRetries"

# Determine worker targets for APT cleanup
$workerTargets = if ($Targets -eq "all") { "workers" } else { $Targets }

try {
    # Prerequisites check
    if (-not $SkipPreFlight) {
        if (-not (Test-Prerequisites)) {
            Write-Error "Pre-flight checks failed. Exiting."
            exit 1
        }
    }

    # Force APT fix if requested
    if ($ForceAptFix) {
        Write-Step "Force fixing APT locks as requested..."
        & "$PSScriptRoot\fix-apt-locks.ps1" -Targets "pi-worker-1,pi-worker-2"
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "APT lock fix reported issues, but continuing..."
        }
    }

    # Deployment attempt with retries
    $deploymentSuccess = $false
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        Write-Step "Deployment attempt $attempt of $MaxRetries"

        try {
            # Prepare nodes for deployment
            Stop-SystemAPTProcesses -NodeTargets $workerTargets
            Clear-APTLocks -NodeTargets $workerTargets

            # Execute Puppet deployment
            if (Invoke-PuppetDeployment -PlanName $Plan -NodeTargets $Targets -Env $Environment) {
                Write-Step "✅ Puppet deployment completed successfully!"
                $deploymentSuccess = $true
                break
            } else {
                Write-Warning "Puppet deployment failed on attempt $attempt"

                if ($attempt -lt $MaxRetries) {
                    Write-Info "Waiting before retry..."
                    Start-Sleep -Seconds 30
                }
            }

        } catch {
            Write-Error "Deployment attempt $attempt failed with error: $($_.Exception.Message)"

            if ($attempt -lt $MaxRetries) {
                Write-Info "Waiting before retry..."
                Start-Sleep -Seconds 30
            }
        }
    }

    if (-not $deploymentSuccess) {
        Write-Error "❌ Deployment failed after $MaxRetries attempts"
        Write-Info "You may need to:"
        Write-Info "1. Check node connectivity manually"
        Write-Info "2. Run APT lock fix script: .\scripts\fix-apt-locks.ps1"
        Write-Info "3. Check system logs on the nodes"
        Write-Info "4. Try deploying to individual nodes"
        exit 1
    }

    # Validate deployment result
    if (Test-DeploymentResult) {
        Write-Step "🎉 Deployment validation successful!"
    } else {
        Write-Warning "⚠️  Deployment completed but validation had issues"
    }

} finally {
    # Always restore APT configuration
    Write-Step "Cleaning up..."
    try {
        Restore-APTConfiguration -NodeTargets $workerTargets
        Write-Info "✅ APT configuration restored"
    } catch {
        Write-Warning "Failed to restore APT configuration: $($_.Exception.Message)"
    }
}

Write-Step "🚀 Deployment script completed!"
Write-Info "Next steps:"
Write-Info "1. Check cluster status: .\Make.ps1 cluster-status"
Write-Info "2. Access services: .\Make.ps1 nifi-ui, .\Make.ps1 grafana-ui"
Write-Info "3. Get kubeconfig: .\Make.ps1 kubeconfig"
