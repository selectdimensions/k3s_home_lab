#!/usr/bin/env pwsh
# Enhanced APT lock resolution script for Pi worker nodes

[CmdletBinding()]
param(
    [string]$Targets = "pi-worker-1,pi-worker-2",
    [int]$MaxRetries = 3,
    [int]$RetryDelay = 10
)

function Write-Step {
    param([string]$Message)
    Write-Host "🔧 $Message" -ForegroundColor Green
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

function Test-NodeConnectivity {
    param([string]$Target)
    Write-Info "Testing connectivity to $Target..."
    $result = & "$PSScriptRoot\..\bolt.ps1" -cmd "command run 'echo connected'" -targets $Target -inventory "inventory.yaml"
    return $LASTEXITCODE -eq 0
}

function Stop-AptProcesses {
    param([string]$Target)
    Write-Info "Stopping APT processes on $Target..."

    $stopCommands = @(
        "sudo systemctl stop apt-daily.service",
        "sudo systemctl stop apt-daily.timer",
        "sudo systemctl stop apt-daily-upgrade.service",
        "sudo systemctl stop apt-daily-upgrade.timer",
        "sudo systemctl stop packagekit.service",
        "sudo pkill -f apt",
        "sudo pkill -f dpkg",
        "sudo pkill -f unattended-upgrade"
    )

    foreach ($cmd in $stopCommands) {
        Write-Info "Running: $cmd"
        & "$PSScriptRoot\..\bolt.ps1" -cmd "command run '$cmd'" -targets $Target -inventory "inventory.yaml"
        Start-Sleep -Seconds 2
    }
}

function Remove-LockFiles {
    param([string]$Target)
    Write-Info "Removing lock files on $Target..."

    $lockFiles = @(
        "/var/lib/apt/lists/lock",
        "/var/cache/apt/archives/lock",
        "/var/lib/dpkg/lock",
        "/var/lib/dpkg/lock-frontend",
        "/var/lib/apt/daily_lock"
    )

    foreach ($lockFile in $lockFiles) {
        Write-Info "Removing: $lockFile"
        & "$PSScriptRoot\..\bolt.ps1" -cmd "command run 'sudo rm -f $lockFile'" -targets $Target -inventory "inventory.yaml"
    }
}

function Repair-AptDatabase {
    param([string]$Target)
    Write-Info "Repairing APT database on $Target..."

    $repairCommands = @(
        "sudo dpkg --configure -a",
        "sudo apt-get clean",
        "sudo apt-get autoclean",
        "sudo apt-get update"
    )

    foreach ($cmd in $repairCommands) {
        Write-Info "Running: $cmd"
        $result = & "$PSScriptRoot\..\bolt.ps1" -cmd "command run '$cmd'" -targets $Target -inventory "inventory.yaml"
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Command failed, but continuing: $cmd"
        }
        Start-Sleep -Seconds 3
    }
}

function Test-AptFunctionality {
    param([string]$Target)
    Write-Info "Testing APT functionality on $Target..."
    $result = & "$PSScriptRoot\..\bolt.ps1" -cmd "command run 'sudo apt-get update'" -targets $Target -inventory "inventory.yaml"
    return $LASTEXITCODE -eq 0
}

function Fix-SingleNode {
    param([string]$Target)

    Write-Step "Fixing APT locks on node: $Target"

    # Test connectivity first
    if (-not (Test-NodeConnectivity -Target $Target)) {
        Write-Error "Cannot connect to $Target. Skipping."
        return $false
    }

    # Stop APT processes
    Stop-AptProcesses -Target $Target
    Start-Sleep -Seconds 5

    # Remove lock files
    Remove-LockFiles -Target $Target
    Start-Sleep -Seconds 2

    # Repair APT database
    Repair-AptDatabase -Target $Target

    # Test if APT is working
    if (Test-AptFunctionality -Target $Target) {
        Write-Step "✅ APT lock fix successful on $Target"
        return $true
    } else {
        Write-Error "APT lock fix failed on $Target"
        return $false
    }
}

# Main execution
Write-Step "🔧 Enhanced APT Lock Resolution Script"
Write-Info "Targets: $Targets"
Write-Info "Max Retries: $MaxRetries"
Write-Info "Retry Delay: $RetryDelay seconds"

$targetList = $Targets -split ','
$failedNodes = @()

foreach ($target in $targetList) {
    $target = $target.Trim()
    $success = $false

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        Write-Info "Attempt $attempt of $MaxRetries for $target"

        if (Fix-SingleNode -Target $target) {
            $success = $true
            break
        } else {
            if ($attempt -lt $MaxRetries) {
                Write-Warning "Retrying in $RetryDelay seconds..."
                Start-Sleep -Seconds $RetryDelay
            }
        }
    }

    if (-not $success) {
        $failedNodes += $target
        Write-Error "Failed to fix APT locks on $target after $MaxRetries attempts"
    }
}

# Summary
if ($failedNodes.Count -eq 0) {
    Write-Step "✅ APT lock fix completed successfully on all nodes!"
    Write-Info "You can now retry the Puppet deployment."
} else {
    Write-Error "❌ APT lock fix failed on the following nodes: $($failedNodes -join ', ')"
    Write-Warning "Manual intervention may be required for these nodes."
    Write-Info "You can try running the script again or check the nodes manually."
    exit 1
}
