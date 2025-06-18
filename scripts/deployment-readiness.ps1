#!/usr/bin/env pwsh
# Deployment Readiness Checklist
# Comprehensive pre-deployment validation for k3s_home_lab

[CmdletBinding()]
param(
    [string]$Environment = "dev",
    [switch]$FixIssues,
    [switch]$GenerateConfig,
    [switch]$DetailedOutput
)

$ErrorActionPreference = "Stop"
if ($DetailedOutput) { $VerbosePreference = "Continue" }

# Global state
$script:ChecklistItems = @()
$script:TotalChecks = 0
$script:PassedChecks = 0
$script:FailedChecks = 0
$script:ActionableItems = @()

function Add-CheckResult {
    param(
        [string]$Category,
        [string]$Check,
        [string]$Status,  # "PASS", "FAIL", "WARN", "INFO"
        [string]$Details = "",
        [string]$Action = ""
    )

    $script:TotalChecks++
    $item = @{
        Category = $Category
        Check = $Check
        Status = $Status
        Details = $Details
        Action = $Action
        Timestamp = Get-Date
    }
    $script:ChecklistItems += $item

    $icon = switch ($Status) {
        "PASS" { "✅"; $script:PassedChecks++ }
        "FAIL" { "❌"; $script:FailedChecks++ }
        "WARN" { "⚠️ " }
        "INFO" { "ℹ️ " }
    }

    $color = switch ($Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        "INFO" { "Cyan" }
    }

    Write-Host "$icon [$Category] $Check" -ForegroundColor $color
    if ($Details) { Write-Host "    $Details" -ForegroundColor DarkGray }
    if ($Action -and $Status -eq "FAIL") {
        $script:ActionableItems += $Action
        Write-Host "    🔧 Action: $Action" -ForegroundColor Magenta
    }
}

function Test-Prerequisites {
    Write-Host ""
    Write-Host "🔍 Prerequisites Check" -ForegroundColor Blue
    Write-Host "════════════════════════" -ForegroundColor Blue

    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -ge 7) {
        Add-CheckResult "Prerequisites" "PowerShell Version" "PASS" "PowerShell $psVersion (recommended)"
    } elseif ($psVersion.Major -ge 5) {
        Add-CheckResult "Prerequisites" "PowerShell Version" "WARN" "PowerShell $psVersion (consider upgrading to 7+)"
    } else {
        Add-CheckResult "Prerequisites" "PowerShell Version" "FAIL" "PowerShell $psVersion (too old)" "Upgrade to PowerShell 7+"
    }

    # Check required tools
    $tools = @{
        "terraform" = @{ required = $true; minVersion = "1.5.0" }
        "git" = @{ required = $true; minVersion = "2.0.0" }
        "docker" = @{ required = $false; minVersion = "20.0.0" }
        "kubectl" = @{ required = $false; minVersion = "1.25.0" }
        "helm" = @{ required = $false; minVersion = "3.10.0" }
    }

    foreach ($tool in $tools.Keys) {
        try {
            $command = Get-Command $tool -ErrorAction Stop
            $version = & $tool --version 2>&1 | Select-Object -First 1

            if ($tools[$tool].required) {
                Add-CheckResult "Prerequisites" "$tool Command" "PASS" "Found: $version"
            } else {
                Add-CheckResult "Prerequisites" "$tool Command" "INFO" "Found: $version (optional)"
            }
        } catch {
            if ($tools[$tool].required) {
                Add-CheckResult "Prerequisites" "$tool Command" "FAIL" "Not found in PATH" "Install $tool"
            } else {
                Add-CheckResult "Prerequisites" "$tool Command" "INFO" "Not found (optional)"
            }
        }
    }

    # Check network connectivity
    try {
        $null = Test-NetConnection -ComputerName "github.com" -Port 443 -InformationLevel Quiet -ErrorAction Stop
        Add-CheckResult "Prerequisites" "Internet Connectivity" "PASS" "Can reach GitHub"
    } catch {
        Add-CheckResult "Prerequisites" "Internet Connectivity" "WARN" "Limited connectivity" "Check network settings"
    }
}

function Test-ProjectStructure {
    Write-Host ""
    Write-Host "📁 Project Structure Check" -ForegroundColor Blue
    Write-Host "═══════════════════════════" -ForegroundColor Blue

    # Critical directories
    $criticalDirs = @(
        @{ path = "terraform/environments/$Environment"; desc = "Environment config" },
        @{ path = "terraform/modules"; desc = "Terraform modules" },
        @{ path = "puppet/plans"; desc = "Puppet plans" },
        @{ path = "puppet/tasks"; desc = "Puppet tasks" },
        @{ path = "k8s/base"; desc = "K8s base config" },
        @{ path = ".github/workflows"; desc = "CI/CD workflows" }
    )

    foreach ($item in $criticalDirs) {
        if (Test-Path $item.path) {
            $fileCount = (Get-ChildItem $item.path -Recurse -File).Count
            Add-CheckResult "Structure" $item.desc "PASS" "$($item.path) ($fileCount files)"
        } else {
            Add-CheckResult "Structure" $item.desc "FAIL" "Missing: $($item.path)" "Create directory structure"
        }
    }

    # Critical files
    $criticalFiles = @(
        @{ path = "Make.ps1"; desc = "Build script" },
        @{ path = "inventory.yaml.example"; desc = "Inventory template" },
        @{ path = "terraform/environments/$Environment/main.tf"; desc = "Environment main config" },
        @{ path = "puppet/bolt-project.yaml"; desc = "Bolt configuration" }
    )

    foreach ($item in $criticalFiles) {
        if (Test-Path $item.path) {
            $size = (Get-Item $item.path).Length
            Add-CheckResult "Structure" $item.desc "PASS" "$($item.path) ($size bytes)"
        } else {
            Add-CheckResult "Structure" $item.desc "FAIL" "Missing: $($item.path)" "Create required file"
        }
    }
}

function Test-Configuration {
    Write-Host ""
    Write-Host "⚙️  Configuration Check" -ForegroundColor Blue
    Write-Host "════════════════════════" -ForegroundColor Blue    # Check inventory configuration
    if (Test-Path "inventory.yaml") {
        try {
            # Validate YAML by testing with bolt inventory show
            $boltResult = & bolt inventory show --inventoryfile inventory.yaml 2>&1
            if ($LASTEXITCODE -eq 0) {
                Add-CheckResult "Configuration" "Inventory File" "PASS" "inventory.yaml exists and is valid"
            } else {
                Add-CheckResult "Configuration" "Inventory File" "FAIL" "Invalid YAML format" "Fix inventory.yaml syntax"
            }

            # Check for placeholder values
            $content = Get-Content "inventory.yaml" -Raw
            if ($content -match "192\.168\.0\.120") {
                Add-CheckResult "Configuration" "Inventory IPs" "INFO" "Using default IP addresses"
            } else {
                Add-CheckResult "Configuration" "Inventory IPs" "PASS" "Custom IP addresses configured"
            }
        } catch {
            Add-CheckResult "Configuration" "Inventory File" "FAIL" "Invalid YAML format" "Fix inventory.yaml syntax"
        }
    } else {
        if (Test-Path "inventory.yaml.example") {
            Add-CheckResult "Configuration" "Inventory File" "WARN" "Using example file" "Copy inventory.yaml.example to inventory.yaml and customize"
        } else {
            Add-CheckResult "Configuration" "Inventory File" "FAIL" "No inventory file found" "Create inventory.yaml"
        }
    }

    # Check Terraform variables
    $tfvarsPath = "terraform/environments/$Environment/terraform.tfvars"
    $tfvarsExamplePath = "terraform/environments/$Environment/terraform.tfvars.example"

    if (Test-Path $tfvarsPath) {
        $tfvarsContent = Get-Content $tfvarsPath -Raw

        # Check for placeholder values
        $placeholders = @("your-email@example.com", "dev-password", "your-github-org")
        $foundPlaceholders = @()
        foreach ($placeholder in $placeholders) {
            if ($tfvarsContent -match [regex]::Escape($placeholder)) {
                $foundPlaceholders += $placeholder
            }
        }

        if ($foundPlaceholders.Count -eq 0) {
            Add-CheckResult "Configuration" "Terraform Variables" "PASS" "terraform.tfvars properly configured"
        } else {
            Add-CheckResult "Configuration" "Terraform Variables" "WARN" "Found placeholders: $($foundPlaceholders -join ', ')" "Update placeholder values"
        }
    } elseif (Test-Path $tfvarsExamplePath) {
        Add-CheckResult "Configuration" "Terraform Variables" "WARN" "Using example file" "Copy terraform.tfvars.example to terraform.tfvars and customize"
    } else {
        Add-CheckResult "Configuration" "Terraform Variables" "FAIL" "No terraform.tfvars found" "Create terraform.tfvars file"
    }

    # Check SSH key configuration
    $sshKeyPath = "$env:USERPROFILE\.ssh\keys\hobby\pi_k3s_cluster_rsa"
    $sshPubKeyPath = "$env:USERPROFILE\.ssh\keys\hobby\pi_k3s_cluster_rsa.pub"

    if ((Test-Path $sshKeyPath) -and (Test-Path $sshPubKeyPath)) {
        Add-CheckResult "Configuration" "SSH Keys" "PASS" "SSH key pair found"
    } else {
        Add-CheckResult "Configuration" "SSH Keys" "WARN" "SSH keys not found in default location" "Generate SSH key pair if needed"
    }
}

function Test-TerraformReadiness {
    Write-Host ""
    Write-Host "🏗️ Terraform Readiness" -ForegroundColor Blue
    Write-Host "═══════════════════════" -ForegroundColor Blue

    $terraformPath = "terraform/environments/$Environment"

    if (-not (Test-Path $terraformPath)) {
        Add-CheckResult "Terraform" "Environment Path" "FAIL" "Path not found: $terraformPath" "Create environment directory"
        return
    }

    try {
        Push-Location $terraformPath

        # Test terraform fmt
        $fmtOutput = terraform fmt -check -diff 2>&1
        if ($LASTEXITCODE -eq 0) {
            Add-CheckResult "Terraform" "Code Formatting" "PASS" "Code is properly formatted"
        } else {
            Add-CheckResult "Terraform" "Code Formatting" "WARN" "Formatting issues found" "Run: terraform fmt"
        }

        # Test terraform init
        $initOutput = terraform init -backend=false 2>&1
        if ($LASTEXITCODE -eq 0) {
            Add-CheckResult "Terraform" "Initialization" "PASS" "Initialization successful"
        } else {
            Add-CheckResult "Terraform" "Initialization" "FAIL" "Init failed: $initOutput" "Fix initialization errors"
        }

        # Test terraform validate
        $validateOutput = terraform validate 2>&1
        if ($LASTEXITCODE -eq 0) {
            Add-CheckResult "Terraform" "Validation" "PASS" "Configuration valid"
        } else {
            Add-CheckResult "Terraform" "Validation" "FAIL" "Validation failed: $validateOutput" "Fix validation errors"
        }

    } catch {
        Add-CheckResult "Terraform" "Testing" "FAIL" "Exception: $_" "Check Terraform installation"
    } finally {
        Pop-Location
    }
}

function Test-PuppetReadiness {
    Write-Host ""
    Write-Host "🎭 Puppet Readiness" -ForegroundColor Blue
    Write-Host "═══════════════════" -ForegroundColor Blue

    try {
        Push-Location puppet # Change to puppet directory

        # Check bolt command
        try {
            $boltVersion = bolt --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                Add-CheckResult "Puppet" "Bolt Command" "PASS" "Bolt available: $boltVersion"
            } else {
                Add-CheckResult "Puppet" "Bolt Command" "FAIL" "Bolt not working" "Install Puppet Bolt"
            }
        } catch {
            Add-CheckResult "Puppet" "Bolt Command" "FAIL" "Bolt not found" "Install Puppet Bolt"
        }        # Check bolt-project.yaml
        if (Test-Path "bolt-project.yaml") {
            try {
                # Simply validate the file exists and has basic content
                $content = Get-Content "bolt-project.yaml" -Raw
                if ($content -match "name:" -and $content -match "modulepath:") {
                    Add-CheckResult "Puppet" "Bolt Configuration" "PASS" "bolt-project.yaml valid"
                } else {
                    Add-CheckResult "Puppet" "Bolt Configuration" "WARN" "bolt-project.yaml incomplete" "Review bolt configuration"
                }
            } catch {
                Add-CheckResult "Puppet" "Bolt Configuration" "FAIL" "Invalid bolt-project.yaml" "Fix YAML syntax"
            }
        } else {
            Add-CheckResult "Puppet" "Bolt Configuration" "FAIL" "bolt-project.yaml missing" "Create bolt configuration"
        }

        # Check essential plans
        $plans = @("deploy_simple.pp", "k3s_deploy.pp")
        foreach ($plan in $plans) {
            $planPath = "plans/$plan"
            if (Test-Path $planPath) {
                Add-CheckResult "Puppet" "Plan: $plan" "PASS" "Plan exists"
            } else {
                Add-CheckResult "Puppet" "Plan: $plan" "FAIL" "Plan missing" "Create plan file"
            }
        }

        # Check essential tasks
        $tasks = @("check_k3s_prereqs", "install_k3s_master", "cluster_status")
        foreach ($task in $tasks) {
            $taskJson = "tasks/$task.json"
            $taskScript = "tasks/$task.sh"

            if ((Test-Path $taskJson) -and (Test-Path $taskScript)) {
                Add-CheckResult "Puppet" "Task: $task" "PASS" "Task complete"
            } else {
                Add-CheckResult "Puppet" "Task: $task" "FAIL" "Task incomplete" "Create task files"
            }
        }

    } catch {
        Add-CheckResult "Puppet" "Testing" "FAIL" "Exception: $_" "Check Puppet setup"
    } finally {
        Pop-Location
    }
}

function Test-SecurityReadiness {
    Write-Host ""
    Write-Host "🔒 Security Readiness" -ForegroundColor Blue
    Write-Host "═══════════════════════" -ForegroundColor Blue

    # Check for secrets in files
    $sensitivePatterns = @(
        @{ pattern = "password\s*=\s*['\`"][^'\`"]*['\`"]"; desc = "Hardcoded passwords" },
        @{ pattern = "secret\s*=\s*['\`"][^'\`"]*['\`"]"; desc = "Hardcoded secrets" },
        @{ pattern = "token\s*=\s*['\`"][^'\`"]*['\`"]"; desc = "Hardcoded tokens" }
    )

    $foundSecrets = @()
    $configFiles = Get-ChildItem -Recurse -Include "*.tf", "*.yaml", "*.yml", "*.ps1" |
                   Where-Object { $_.FullName -notmatch "\.git|node_modules|\.terraform" }

    foreach ($file in $configFiles) {
        $content = Get-Content $file.FullName -Raw
        foreach ($pattern in $sensitivePatterns) {
            if ($content -match $pattern.pattern) {
                $foundSecrets += "$($file.Name): $($pattern.desc)"
            }
        }
    }

    if ($foundSecrets.Count -eq 0) {
        Add-CheckResult "Security" "Hardcoded Secrets" "PASS" "No hardcoded secrets found"
    } else {
        Add-CheckResult "Security" "Hardcoded Secrets" "WARN" "Found potential secrets: $($foundSecrets -join ', ')" "Review and use variables/secrets management"
    }

    # Check gitignore
    if (Test-Path ".gitignore") {
        $gitignoreContent = Get-Content ".gitignore" -Raw
        $requiredIgnores = @("*.tfstate", "*.tfvars", ".terraform/", "bolt-debug.log")
        $missingIgnores = @()

        foreach ($ignore in $requiredIgnores) {
            if ($gitignoreContent -notmatch [regex]::Escape($ignore)) {
                $missingIgnores += $ignore
            }
        }

        if ($missingIgnores.Count -eq 0) {
            Add-CheckResult "Security" "Git Ignore" "PASS" "All sensitive files ignored"
        } else {
            Add-CheckResult "Security" "Git Ignore" "WARN" "Missing ignores: $($missingIgnores -join ', ')" "Update .gitignore"
        }
    } else {
        Add-CheckResult "Security" "Git Ignore" "FAIL" ".gitignore not found" "Create .gitignore file"
    }
}

function Generate-ConfigurationFiles {
    Write-Host ""
    Write-Host "🔧 Generating Configuration Files" -ForegroundColor Blue
    Write-Host "═══════════════════════════════════" -ForegroundColor Blue

    # Generate inventory.yaml if missing
    if (-not (Test-Path "inventory.yaml") -and (Test-Path "inventory.yaml.example")) {
        Copy-Item "inventory.yaml.example" "inventory.yaml"
        Add-CheckResult "Generation" "Inventory File" "INFO" "Created inventory.yaml from example"
    }

    # Generate terraform.tfvars if missing
    $tfvarsPath = "terraform/environments/$Environment/terraform.tfvars"
    $tfvarsExamplePath = "terraform/environments/$Environment/terraform.tfvars.example"

    if (-not (Test-Path $tfvarsPath) -and (Test-Path $tfvarsExamplePath)) {
        Copy-Item $tfvarsExamplePath $tfvarsPath
        Add-CheckResult "Generation" "Terraform Variables" "INFO" "Created terraform.tfvars from example"
    }

    # Generate SSH keys if missing
    $sshKeyPath = "$env:USERPROFILE\.ssh\id_rsa"
    if (-not (Test-Path $sshKeyPath)) {
        Add-CheckResult "Generation" "SSH Keys" "INFO" "Consider generating SSH keys with: ssh-keygen -t rsa -b 4096"
    }
}

function Generate-DeploymentPlan {
    Write-Host ""
    Write-Host "📋 Deployment Plan" -ForegroundColor Blue
    Write-Host "══════════════════" -ForegroundColor Blue

    $plan = @()

    if ($script:FailedChecks -eq 0) {
        $plan += "✅ All critical checks passed - ready for deployment!"
        $plan += ""
        $plan += "Recommended deployment steps:"
        $plan += "1. .\Make.ps1 terraform-init -Environment $Environment"
        $plan += "2. .\Make.ps1 terraform-plan -Environment $Environment"
        $plan += "3. .\Make.ps1 terraform-apply -Environment $Environment"
        $plan += "4. .\Make.ps1 puppet-deploy -Environment $Environment"
        $plan += "5. .\Make.ps1 cluster-status"
        $plan += ""
        $plan += "Or use quick deploy:"
        $plan += ".\Make.ps1 quick-deploy -Environment $Environment"
    } else {
        $plan += "⚠️  Critical issues found - fix before deployment:"
        $plan += ""
        foreach ($action in $script:ActionableItems) {
            $plan += "• $action"
        }
        $plan += ""
        $plan += "After fixing issues, re-run:"
        $plan += ".\scripts\deployment-readiness.ps1 -Environment $Environment"
    }

    foreach ($line in $plan) {
        if ($line -match "^✅|^⚠️") {
            Write-Host $line -ForegroundColor Green
        } elseif ($line -match "^•") {
            Write-Host $line -ForegroundColor Red
        } elseif ($line -match "^\d+\.|^\\") {
            Write-Host $line -ForegroundColor Cyan
        } else {
            Write-Host $line
        }
    }
}

function Generate-Summary {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host "                    📊 READINESS SUMMARY                        " -ForegroundColor Blue
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Blue

    Write-Host ""
    Write-Host "🎯 Environment: $Environment" -ForegroundColor Yellow
    Write-Host "⏰ Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📈 Check Summary:" -ForegroundColor Yellow
    Write-Host "   Total Checks:  $script:TotalChecks"
    Write-Host "   ✅ Passed:      $script:PassedChecks" -ForegroundColor Green
    Write-Host "   ❌ Failed:      $script:FailedChecks" -ForegroundColor Red

    $readinessScore = if ($script:TotalChecks -gt 0) {
        [math]::Round(($script:PassedChecks / $script:TotalChecks) * 100, 1)
    } else { 0 }

    $scoreColor = if ($readinessScore -ge 90) { "Green" } elseif ($readinessScore -ge 70) { "Yellow" } else { "Red" }
    Write-Host "   📊 Readiness:   $readinessScore%" -ForegroundColor $scoreColor

    Write-Host ""

    if ($script:FailedChecks -eq 0) {
        Write-Host "🎉 Deployment ready! All critical checks passed." -ForegroundColor Green
    } else {
        Write-Host "🚨 Not ready for deployment. Please address failed checks." -ForegroundColor Red
    }

    # Save detailed report
    $reportPath = "deployment-readiness-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $reportData = @{
        Environment = $Environment
        Timestamp = Get-Date
        ReadinessScore = $readinessScore
        Summary = @{
            TotalChecks = $script:TotalChecks
            PassedChecks = $script:PassedChecks
            FailedChecks = $script:FailedChecks
        }
        CheckResults = $script:ChecklistItems
        ActionableItems = $script:ActionableItems
    }

    $reportData | ConvertTo-Json -Depth 10 | Out-File $reportPath -Encoding UTF8
    Write-Host "📄 Detailed report saved to: $reportPath" -ForegroundColor Cyan
}

# Main execution
Write-Host "🚀 k3s_home_lab Deployment Readiness Check" -ForegroundColor Blue
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host ""

try {
    Test-Prerequisites
    Test-ProjectStructure
    Test-Configuration
    Test-TerraformReadiness
    Test-PuppetReadiness
    Test-SecurityReadiness

    if ($GenerateConfig) {
        Generate-ConfigurationFiles
    }

    Generate-DeploymentPlan
    Generate-Summary

} catch {
    Write-Host "❌ Readiness check failed: $_" -ForegroundColor Red
    exit 1
}

# Exit with appropriate code
if ($script:FailedChecks -gt 0) {
    exit 1
} else {
    exit 0
}
