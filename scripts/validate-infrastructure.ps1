#!/usr/bin/env pwsh
# Comprehensive Infrastructure Validation Script
# Tests all components of the k3s_home_lab project

[CmdletBinding()]
param(
    [string]$Environment = "dev",
    [switch]$SkipPuppet,
    [switch]$SkipTerraform,
    [switch]$SkipK8s,
    [switch]$Verbose
)

# Set error action and verbose preference
$ErrorActionPreference = "Stop"
if ($Verbose) { $VerbosePreference = "Continue" }

# Colors for output
function Write-TestStep {
    param([string]$Message)
    Write-Host "🔍 $Message" -ForegroundColor Cyan
}

function Write-TestSuccess {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-TestFailure {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-TestWarning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

# Test results tracking
$script:TestResults = @()
$script:TotalTests = 0
$script:PassedTests = 0
$script:FailedTests = 0
$script:WarningTests = 0

function Add-TestResult {
    param(
        [string]$TestName,
        [string]$Status,  # "PASS", "FAIL", "WARN"
        [string]$Details = ""
    )

    $script:TotalTests++
    $result = @{
        TestName = $TestName
        Status = $Status
        Details = $Details
        Timestamp = Get-Date
    }
    $script:TestResults += $result

    switch ($Status) {
        "PASS" {
            $script:PassedTests++
            Write-TestSuccess "$TestName"
            if ($Details) { Write-Verbose "  Details: $Details" }
        }
        "FAIL" {
            $script:FailedTests++
            Write-TestFailure "$TestName"
            if ($Details) { Write-Host "  Error: $Details" -ForegroundColor Red }
        }
        "WARN" {
            $script:WarningTests++
            Write-TestWarning "$TestName"
            if ($Details) { Write-Host "  Warning: $Details" -ForegroundColor Yellow }
        }
    }
}

function Test-Prerequisites {
    Write-TestStep "Testing Prerequisites"

    # Test PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -ge 5) {
        Add-TestResult "PowerShell Version" "PASS" "Version $psVersion"
    } else {
        Add-TestResult "PowerShell Version" "FAIL" "Version $psVersion is too old (requires 5.0+)"
    }

    # Test required commands
    $requiredCommands = @("git", "terraform", "docker")
    foreach ($cmd in $requiredCommands) {
        try {
            $null = Get-Command $cmd -ErrorAction Stop
            Add-TestResult "Command: $cmd" "PASS" "Available"
        } catch {
            Add-TestResult "Command: $cmd" "FAIL" "Not found in PATH"
        }
    }

    # Test Puppet Bolt availability
    try {
        Push-Location puppet
        $boltVersion = & bolt --version 2>&1
        Pop-Location
        if ($LASTEXITCODE -eq 0) {
            Add-TestResult "Puppet Bolt" "PASS" "Version: $boltVersion"
        } else {
            Add-TestResult "Puppet Bolt" "WARN" "Available but may have issues"
        }
    } catch {
        Add-TestResult "Puppet Bolt" "FAIL" "Not available or not working"
    }
}

function Test-ProjectStructure {
    Write-TestStep "Testing Project Structure"

    # Test critical directories
    $criticalDirs = @(
        "terraform/environments/dev",
        "terraform/environments/staging",
        "terraform/environments/prod",
        "terraform/modules",
        "puppet/plans",
        "puppet/tasks",
        "puppet/site-modules",
        "k8s/base",
        "k8s/overlays",
        ".github/workflows"
    )

    foreach ($dir in $criticalDirs) {
        if (Test-Path $dir) {
            Add-TestResult "Directory: $dir" "PASS" "Exists"
        } else {
            Add-TestResult "Directory: $dir" "FAIL" "Missing"
        }
    }

    # Test critical files
    $criticalFiles = @(
        "Make.ps1",
        "inventory.yaml.example",
        "terraform/environments/$Environment/main.tf",
        "puppet/bolt-project.yaml",
        "puppet/Puppetfile",
        ".github/workflows/setup.yml"
    )

    foreach ($file in $criticalFiles) {
        if (Test-Path $file) {
            Add-TestResult "File: $file" "PASS" "Exists"
        } else {
            Add-TestResult "File: $file" "FAIL" "Missing"
        }
    }
}

function Test-TerraformConfiguration {
    if ($SkipTerraform) {
        Write-TestStep "Skipping Terraform tests"
        return
    }

    Write-TestStep "Testing Terraform Configuration"

    $terraformPath = "terraform/environments/$Environment"

    if (-not (Test-Path $terraformPath)) {
        Add-TestResult "Terraform Environment" "FAIL" "Path $terraformPath not found"
        return
    }

    try {
        Push-Location $terraformPath

        # Test terraform fmt
        $fmtResult = terraform fmt -check -diff 2>&1
        if ($LASTEXITCODE -eq 0) {
            Add-TestResult "Terraform Format" "PASS" "Code is properly formatted"
        } else {
            Add-TestResult "Terraform Format" "WARN" "Code formatting issues found"
        }

        # Test terraform init
        $initResult = terraform init -backend=false 2>&1
        if ($LASTEXITCODE -eq 0) {
            Add-TestResult "Terraform Init" "PASS" "Initialization successful"
        } else {
            Add-TestResult "Terraform Init" "FAIL" "Initialization failed: $initResult"
            return
        }

        # Test terraform validate
        $validateResult = terraform validate 2>&1
        if ($LASTEXITCODE -eq 0) {
            Add-TestResult "Terraform Validate" "PASS" "Configuration is valid"
        } else {
            Add-TestResult "Terraform Validate" "FAIL" "Validation failed: $validateResult"
        }

        # Test terraform plan (if tfvars.example exists)
        $tfvarsExample = "terraform.tfvars.example"
        if (Test-Path $tfvarsExample) {
            # Copy example to actual for testing
            Copy-Item $tfvarsExample "terraform.tfvars"

            $planResult = terraform plan -detailed-exitcode 2>&1
            $planExitCode = $LASTEXITCODE

            Remove-Item "terraform.tfvars" -ErrorAction SilentlyContinue

            if ($planExitCode -eq 0) {
                Add-TestResult "Terraform Plan" "PASS" "Plan successful (no changes)"
            } elseif ($planExitCode -eq 2) {
                Add-TestResult "Terraform Plan" "PASS" "Plan successful (changes detected)"
            } else {
                Add-TestResult "Terraform Plan" "FAIL" "Plan failed: $planResult"
            }
        } else {
            Add-TestResult "Terraform Plan" "WARN" "No terraform.tfvars.example found for testing"
        }

    } catch {
        Add-TestResult "Terraform Testing" "FAIL" "Exception: $_"
    } finally {
        Pop-Location
    }
}

function Test-PuppetConfiguration {
    if ($SkipPuppet) {
        Write-TestStep "Skipping Puppet tests"
        return
    }

    Write-TestStep "Testing Puppet Configuration"

    try {
        Push-Location puppet

        # Test Puppetfile syntax
        if (Test-Path "Puppetfile") {
            Add-TestResult "Puppetfile" "PASS" "File exists"
        } else {
            Add-TestResult "Puppetfile" "FAIL" "Puppetfile not found"
        }

        # Test bolt-project.yaml
        if (Test-Path "bolt-project.yaml") {
            try {
                $boltConfig = Get-Content "bolt-project.yaml" | ConvertFrom-Yaml -ErrorAction Stop
                Add-TestResult "Bolt Project Config" "PASS" "Valid YAML configuration"
            } catch {
                Add-TestResult "Bolt Project Config" "FAIL" "Invalid YAML: $_"
            }
        } else {
            Add-TestResult "Bolt Project Config" "FAIL" "bolt-project.yaml not found"
        }

        # Test Puppet syntax for all .pp files
        $puppetFiles = Get-ChildItem -Recurse -Filter "*.pp" -Path "site-modules", "manifests", "plans" -ErrorAction SilentlyContinue
        $puppetSyntaxErrors = 0

        foreach ($file in $puppetFiles) {
            try {
                $parseResult = puppet parser validate $file.FullName 2>&1
                if ($LASTEXITCODE -ne 0) {
                    $puppetSyntaxErrors++
                    Write-Verbose "Puppet syntax error in $($file.Name): $parseResult"
                }
            } catch {
                $puppetSyntaxErrors++
                Write-Verbose "Error checking $($file.Name): $_"
            }
        }

        if ($puppetSyntaxErrors -eq 0) {
            Add-TestResult "Puppet Syntax" "PASS" "All .pp files have valid syntax ($($puppetFiles.Count) files checked)"
        } else {
            Add-TestResult "Puppet Syntax" "FAIL" "$puppetSyntaxErrors syntax errors found"
        }

        # Test Puppet plans exist
        $expectedPlans = @("deploy_simple.pp", "k3s_deploy.pp", "deploy.pp")
        foreach ($plan in $expectedPlans) {
            $planPath = "plans/$plan"
            if (Test-Path $planPath) {
                Add-TestResult "Puppet Plan: $plan" "PASS" "Plan exists"
            } else {
                Add-TestResult "Puppet Plan: $plan" "FAIL" "Plan not found"
            }
        }

        # Test Puppet tasks exist
        $expectedTasks = @("check_k3s_prereqs", "install_k3s_master", "install_k3s_worker", "cluster_status")
        foreach ($task in $expectedTasks) {
            $taskJson = "tasks/$task.json"
            $taskScript = "tasks/$task.sh"

            if ((Test-Path $taskJson) -and (Test-Path $taskScript)) {
                Add-TestResult "Puppet Task: $task" "PASS" "Task complete (JSON + script)"
            } elseif (Test-Path $taskJson) {
                Add-TestResult "Puppet Task: $task" "WARN" "Task JSON exists but script missing"
            } else {
                Add-TestResult "Puppet Task: $task" "FAIL" "Task not found"
            }
        }

    } catch {
        Add-TestResult "Puppet Testing" "FAIL" "Exception: $_"
    } finally {
        Pop-Location
    }
}

function Test-K8sConfiguration {
    if ($SkipK8s) {
        Write-TestStep "Skipping Kubernetes tests"
        return
    }

    Write-TestStep "Testing Kubernetes Configuration"

    # Test YAML syntax for all k8s files
    $k8sFiles = Get-ChildItem -Recurse -Filter "*.yaml" -Path "k8s" -ErrorAction SilentlyContinue
    $yamlErrors = 0

    foreach ($file in $k8sFiles) {
        try {
            $null = Get-Content $file.FullName | ConvertFrom-Yaml -ErrorAction Stop
        } catch {
            $yamlErrors++
            Write-Verbose "YAML error in $($file.Name): $_"
        }
    }

    if ($yamlErrors -eq 0) {
        Add-TestResult "Kubernetes YAML Syntax" "PASS" "All YAML files valid ($($k8sFiles.Count) files checked)"
    } else {
        Add-TestResult "Kubernetes YAML Syntax" "FAIL" "$yamlErrors YAML syntax errors found"
    }

    # Test kustomization files
    $kustomizations = Get-ChildItem -Recurse -Filter "kustomization.yaml" -Path "k8s" -ErrorAction SilentlyContinue
    foreach ($kustomization in $kustomizations) {
        $dir = $kustomization.Directory
        try {
            Push-Location $dir
            if (Get-Command kubectl -ErrorAction SilentlyContinue) {
                $dryRunResult = kubectl kustomize . 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Add-TestResult "Kustomization: $($dir.Name)" "PASS" "Kustomize builds successfully"
                } else {
                    Add-TestResult "Kustomization: $($dir.Name)" "FAIL" "Kustomize failed: $dryRunResult"
                }
            } else {
                Add-TestResult "Kustomization: $($dir.Name)" "WARN" "kubectl not available for testing"
            }
        } catch {
            Add-TestResult "Kustomization: $($dir.Name)" "FAIL" "Exception: $_"
        } finally {
            Pop-Location
        }
    }

    # Test Helm values files
    $helmValues = Get-ChildItem -Filter "*-values.yaml" -Path "k8s/helm-values" -ErrorAction SilentlyContinue
    foreach ($values in $helmValues) {
        try {
            $null = Get-Content $values.FullName | ConvertFrom-Yaml -ErrorAction Stop
            Add-TestResult "Helm Values: $($values.Name)" "PASS" "Valid YAML"
        } catch {
            Add-TestResult "Helm Values: $($values.Name)" "FAIL" "Invalid YAML: $_"
        }
    }
}

function Test-GitHubActions {
    Write-TestStep "Testing GitHub Actions Workflows"

    $workflows = Get-ChildItem -Filter "*.yml" -Path ".github/workflows" -ErrorAction SilentlyContinue

    foreach ($workflow in $workflows) {
        try {
            $content = Get-Content $workflow.FullName | ConvertFrom-Yaml -ErrorAction Stop

            # Basic workflow validation
            if ($content.on -and $content.jobs) {
                Add-TestResult "Workflow: $($workflow.Name)" "PASS" "Valid workflow structure"
            } else {
                Add-TestResult "Workflow: $($workflow.Name)" "FAIL" "Missing required fields (on, jobs)"
            }
        } catch {
            Add-TestResult "Workflow: $($workflow.Name)" "FAIL" "Invalid YAML: $_"
        }
    }

    # Check for essential workflows
    $essentialWorkflows = @("ci-cd-main.yml", "terraform-ci.yml", "puppet-ci.yml", "setup.yml")
    foreach ($workflow in $essentialWorkflows) {
        $path = ".github/workflows/$workflow"
        if (Test-Path $path) {
            Add-TestResult "Essential Workflow: $workflow" "PASS" "Workflow exists"
        } else {
            Add-TestResult "Essential Workflow: $workflow" "WARN" "Workflow missing (optional but recommended)"
        }
    }
}

function Test-MakeScript {
    Write-TestStep "Testing Make.ps1 Script"

    if (-not (Test-Path "Make.ps1")) {
        Add-TestResult "Make.ps1" "FAIL" "Script not found"
        return
    }

    try {
        # Test script syntax
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content "Make.ps1" -Raw), [ref]$null)
        Add-TestResult "Make.ps1 Syntax" "PASS" "PowerShell syntax valid"
    } catch {
        Add-TestResult "Make.ps1 Syntax" "FAIL" "PowerShell syntax error: $_"
        return
    }

    # Test help command
    try {
        $helpOutput = & ".\Make.ps1" help 2>&1
        if ($helpOutput -match "Available Commands") {
            Add-TestResult "Make.ps1 Help" "PASS" "Help command works"
        } else {
            Add-TestResult "Make.ps1 Help" "FAIL" "Help command doesn't show expected output"
        }
    } catch {
        Add-TestResult "Make.ps1 Help" "FAIL" "Help command failed: $_"
    }

    # Test essential commands exist
    $makeContent = Get-Content "Make.ps1" -Raw
    $essentialCommands = @("terraform-init", "terraform-plan", "terraform-apply", "puppet-deploy", "quick-deploy")

    foreach ($cmd in $essentialCommands) {
        if ($makeContent -match [regex]::Escape("`"$cmd`"")) {
            Add-TestResult "Make.ps1 Command: $cmd" "PASS" "Command implemented"
        } else {
            Add-TestResult "Make.ps1 Command: $cmd" "FAIL" "Command not found in script"
        }
    }
}

function Generate-Report {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host "                    📊 VALIDATION REPORT                        " -ForegroundColor Blue
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host ""
    Write-Host "🎯 Environment: $Environment" -ForegroundColor Yellow
    Write-Host "⏰ Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📈 Test Summary:" -ForegroundColor Yellow
    Write-Host "   Total Tests:   $script:TotalTests"
    Write-Host "   ✅ Passed:      $script:PassedTests" -ForegroundColor Green
    Write-Host "   ❌ Failed:      $script:FailedTests" -ForegroundColor Red
    Write-Host "   ⚠️  Warnings:    $script:WarningTests" -ForegroundColor Yellow

    $successRate = if ($script:TotalTests -gt 0) {
        [math]::Round(($script:PassedTests / $script:TotalTests) * 100, 1)
    } else { 0 }
    Write-Host "   📊 Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 70) { "Yellow" } else { "Red" })

    Write-Host ""

    # Show failed tests
    if ($script:FailedTests -gt 0) {
        Write-Host "❌ Failed Tests:" -ForegroundColor Red
        $script:TestResults | Where-Object { $_.Status -eq "FAIL" } | ForEach-Object {
            Write-Host "   • $($_.TestName)" -ForegroundColor Red
            if ($_.Details) {
                Write-Host "     $($_.Details)" -ForegroundColor DarkRed
            }
        }
        Write-Host ""
    }

    # Show warnings
    if ($script:WarningTests -gt 0) {
        Write-Host "⚠️  Warnings:" -ForegroundColor Yellow
        $script:TestResults | Where-Object { $_.Status -eq "WARN" } | ForEach-Object {
            Write-Host "   • $($_.TestName)" -ForegroundColor Yellow
            if ($_.Details) {
                Write-Host "     $($_.Details)" -ForegroundColor DarkYellow
            }
        }
        Write-Host ""
    }

    # Recommendations
    Write-Host "🔧 Recommendations:" -ForegroundColor Magenta
    if ($script:FailedTests -eq 0 -and $script:WarningTests -eq 0) {
        Write-Host "   🎉 Excellent! All tests passed. Your infrastructure is ready for deployment." -ForegroundColor Green
        Write-Host "   💡 Next steps:" -ForegroundColor Cyan
        Write-Host "      1. Run: .\Make.ps1 quick-deploy -Environment $Environment"
        Write-Host "      2. Verify deployment with: .\Make.ps1 cluster-status"
    } elseif ($script:FailedTests -eq 0) {
        Write-Host "   ✅ Good! No failures, but some warnings to address." -ForegroundColor Yellow
        Write-Host "   💡 Consider fixing warnings before production deployment." -ForegroundColor Cyan
    } else {
        Write-Host "   ⚠️  Critical issues found. Please fix failed tests before deploying." -ForegroundColor Red
        Write-Host "   💡 Focus on fixing the failed tests listed above." -ForegroundColor Cyan
    }

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Blue

    # Save detailed report
    $reportPath = "validation-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $reportData = @{
        Environment = $Environment
        Timestamp = Get-Date
        Summary = @{
            TotalTests = $script:TotalTests
            PassedTests = $script:PassedTests
            FailedTests = $script:FailedTests
            WarningTests = $script:WarningTests
            SuccessRate = $successRate
        }
        TestResults = $script:TestResults
    }

    $reportData | ConvertTo-Json -Depth 10 | Out-File $reportPath -Encoding UTF8
    Write-Host "📄 Detailed report saved to: $reportPath" -ForegroundColor Cyan

    # Exit with appropriate code
    if ($script:FailedTests -gt 0) {
        exit 1
    } else {
        exit 0
    }
}

# Main execution
Write-Host ""
Write-Host "🚀 k3s_home_lab Infrastructure Validation" -ForegroundColor Blue
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Starting comprehensive validation..." -ForegroundColor Cyan
Write-Host ""

try {
    Test-Prerequisites
    Test-ProjectStructure
    Test-TerraformConfiguration
    Test-PuppetConfiguration
    Test-K8sConfiguration
    Test-GitHubActions
    Test-MakeScript
} catch {
    Write-TestFailure "Validation script error: $_"
    Add-TestResult "Script Execution" "FAIL" "Unhandled exception: $_"
} finally {
    Generate-Report
}
