#!/usr/bin/env pwsh
# Terraform Module Testing Script
# Tests all Terraform modules individually and in environments

[CmdletBinding()]
param(
    [string]$Environment = "dev",
    [string]$ModuleName = "",
    [switch]$SkipValidation,
    [switch]$SkipPlan,
    [switch]$CleanUp
)

$ErrorActionPreference = "Stop"

function Write-TestHeader {
    param([string]$Message)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host " $Message" -ForegroundColor Blue
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Blue
}

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

# Test individual modules
function Test-TerraformModule {
    param([string]$ModulePath)

    $moduleName = Split-Path $ModulePath -Leaf
    Write-TestStep "Testing module: $moduleName"

    if (-not (Test-Path $ModulePath)) {
        Write-TestFailure "Module path not found: $ModulePath"
        return $false
    }

    try {
        Push-Location $ModulePath

        # Check for required files
        $requiredFiles = @("main.tf", "variables.tf", "outputs.tf")
        foreach ($file in $requiredFiles) {
            if (Test-Path $file) {
                Write-Verbose "✓ Found $file"
            } else {
                Write-TestFailure "$moduleName: Missing $file"
                return $false
            }
        }

        # Test terraform init
        Write-TestStep "Initializing module: $moduleName"
        $initResult = terraform init -backend=false 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-TestFailure "$moduleName: Init failed - $initResult"
            return $false
        }

        # Test terraform validate
        if (-not $SkipValidation) {
            Write-TestStep "Validating module: $moduleName"
            $validateResult = terraform validate 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-TestFailure "$moduleName: Validation failed - $validateResult"
                return $false
            }
        }

        Write-TestSuccess "$moduleName: Module tests passed"
        return $true

    } catch {
        Write-TestFailure "$moduleName: Exception - $_"
        return $false
    } finally {
        Pop-Location
    }
}

# Test environment configuration
function Test-EnvironmentConfig {
    param([string]$EnvPath)

    $envName = Split-Path $EnvPath -Leaf
    Write-TestStep "Testing environment: $envName"

    if (-not (Test-Path $EnvPath)) {
        Write-TestFailure "Environment path not found: $EnvPath"
        return $false
    }

    try {
        Push-Location $EnvPath

        # Check for required files
        if (-not (Test-Path "main.tf")) {
            Write-TestFailure "$envName: Missing main.tf"
            return $false
        }

        # Test terraform init
        Write-TestStep "Initializing environment: $envName"
        $initResult = terraform init -backend=false 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-TestFailure "$envName: Init failed - $initResult"
            return $false
        }

        # Test terraform validate
        if (-not $SkipValidation) {
            Write-TestStep "Validating environment: $envName"
            $validateResult = terraform validate 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-TestFailure "$envName: Validation failed - $validateResult"
                return $false
            }
        }

        # Test terraform plan if tfvars.example exists
        if (-not $SkipPlan -and (Test-Path "terraform.tfvars.example")) {
            Write-TestStep "Planning environment: $envName"

            # Create test tfvars
            Copy-Item "terraform.tfvars.example" "terraform.tfvars"

            # Update with test values
            $tfvarsContent = Get-Content "terraform.tfvars" -Raw
            $tfvarsContent = $tfvarsContent -replace 'your-email@example.com', 'test@example.com'
            $tfvarsContent = $tfvarsContent -replace 'your-github-org', 'test-org'
            $tfvarsContent = $tfvarsContent -replace 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK', ''
            $tfvarsContent | Out-File "terraform.tfvars" -Encoding UTF8

            $planResult = terraform plan -detailed-exitcode 2>&1
            $planExitCode = $LASTEXITCODE

            # Clean up
            Remove-Item "terraform.tfvars" -ErrorAction SilentlyContinue

            if ($planExitCode -eq 0 -or $planExitCode -eq 2) {
                Write-TestSuccess "$envName: Plan successful"
            } else {
                Write-TestFailure "$envName: Plan failed - $planResult"
                return $false
            }
        }

        Write-TestSuccess "$envName: Environment tests passed"
        return $true

    } catch {
        Write-TestFailure "$envName: Exception - $_"
        return $false
    } finally {
        Pop-Location
    }
}

# Clean up test artifacts
function Invoke-Cleanup {
    Write-TestStep "Cleaning up test artifacts"

    # Find and remove .terraform directories
    $terraformDirs = Get-ChildItem -Recurse -Directory -Name ".terraform" -Path "terraform" -ErrorAction SilentlyContinue
    foreach ($dir in $terraformDirs) {
        $fullPath = "terraform/$dir"
        Write-Verbose "Removing $fullPath"
        Remove-Item $fullPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Remove terraform.tfstate files
    $stateFiles = Get-ChildItem -Recurse -Filter "terraform.tfstate*" -Path "terraform" -ErrorAction SilentlyContinue
    foreach ($file in $stateFiles) {
        Write-Verbose "Removing $($file.FullName)"
        Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
    }

    # Remove .terraform.lock.hcl files
    $lockFiles = Get-ChildItem -Recurse -Filter ".terraform.lock.hcl" -Path "terraform" -ErrorAction SilentlyContinue
    foreach ($file in $lockFiles) {
        Write-Verbose "Removing $($file.FullName)"
        Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
    }

    Write-TestSuccess "Cleanup completed"
}

# Main execution
Write-TestHeader "🏗️ Terraform Module and Environment Testing"

$testResults = @()
$totalTests = 0
$passedTests = 0

try {
    # Test specific module if provided
    if ($ModuleName) {
        $modulePath = "terraform/modules/$ModuleName"
        $totalTests++
        if (Test-TerraformModule $modulePath) {
            $passedTests++
            $testResults += "✅ Module: $ModuleName"
        } else {
            $testResults += "❌ Module: $ModuleName"
        }
    } else {
        # Test all modules
        Write-TestHeader "📦 Testing Terraform Modules"
        $modules = Get-ChildItem -Directory -Path "terraform/modules" -ErrorAction SilentlyContinue

        foreach ($module in $modules) {
            $totalTests++
            if (Test-TerraformModule $module.FullName) {
                $passedTests++
                $testResults += "✅ Module: $($module.Name)"
            } else {
                $testResults += "❌ Module: $($module.Name)"
            }
        }

        # Test environment configurations
        Write-TestHeader "🌍 Testing Environment Configurations"
        $environments = @("dev", "staging", "prod")

        if ($Environment -ne "all") {
            $environments = @($Environment)
        }

        foreach ($env in $environments) {
            $envPath = "terraform/environments/$env"
            if (Test-Path $envPath) {
                $totalTests++
                if (Test-EnvironmentConfig $envPath) {
                    $passedTests++
                    $testResults += "✅ Environment: $env"
                } else {
                    $testResults += "❌ Environment: $env"
                }
            } else {
                Write-TestFailure "Environment not found: $env"
                $testResults += "❌ Environment: $env (not found)"
            }
        }
    }

    # Generate summary
    Write-TestHeader "📊 Test Summary"

    foreach ($result in $testResults) {
        Write-Host $result
    }

    Write-Host ""
    Write-Host "Total Tests: $totalTests" -ForegroundColor Yellow
    Write-Host "Passed: $passedTests" -ForegroundColor Green
    Write-Host "Failed: $($totalTests - $passedTests)" -ForegroundColor Red

    $successRate = if ($totalTests -gt 0) {
        [math]::Round(($passedTests / $totalTests) * 100, 1)
    } else { 0 }
    Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 70) { "Yellow" } else { "Red" })

    if ($passedTests -eq $totalTests) {
        Write-TestSuccess "🎉 All Terraform tests passed!"
        $exitCode = 0
    } else {
        Write-TestFailure "🚨 Some Terraform tests failed!"
        $exitCode = 1
    }

} catch {
    Write-TestFailure "Test execution failed: $_"
    $exitCode = 1
} finally {
    if ($CleanUp) {
        Invoke-Cleanup
    }
}

Write-Host ""
Write-Host "💡 Next steps:" -ForegroundColor Cyan
if ($exitCode -eq 0) {
    Write-Host "   • All tests passed! Ready for deployment" -ForegroundColor Green
    Write-Host "   • Run: .\Make.ps1 terraform-plan -Environment $Environment" -ForegroundColor Cyan
    Write-Host "   • Run: .\Make.ps1 terraform-apply -Environment $Environment" -ForegroundColor Cyan
} else {
    Write-Host "   • Fix the failed tests above" -ForegroundColor Red
    Write-Host "   • Re-run tests: .\scripts\test-terraform.ps1" -ForegroundColor Cyan
}

exit $exitCode
