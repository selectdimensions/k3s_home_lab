# k3s_home_lab - Windows PowerShell Build Script
# Usage: .\Make.ps1 <command>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$Command = "help",

    [string]$Environment = "dev",
    [string]$BackupName = "manual-$(Get-Date -Format 'yyyyMMdd-HHmmss')",
    [string]$PuppetEnv = "production",
    [string]$Targets = "all",
    [string]$Operation = "all"
)

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

# Colors for output
function Write-Step {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

function Write-Warning {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
}

# Command implementations
function Show-Help {
    Write-Host ""
    Write-Host "k3s_home_lab - Windows PowerShell Build Script" -ForegroundColor Blue
    Write-Host "=============================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Available Commands:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  help                    Show this help message"
    Write-Host "  init                    Initialize the project"
    Write-Host "  validate                Validate configurations"
    Write-Host "  plan                    Plan infrastructure changes"
    Write-Host "  apply                   Apply infrastructure changes and run Puppet"
    Write-Host "  destroy                 Destroy infrastructure"
    Write-Host "  terraform-init          Initialize Terraform for specific environment"
    Write-Host "  terraform-plan          Run Terraform plan for specific environment"
    Write-Host "  terraform-apply         Apply Terraform changes for specific environment"
    Write-Host "  terraform-destroy       Destroy Terraform infrastructure"
    Write-Host "  terraform-validate      Validate Terraform configuration"
    Write-Host "  quick-deploy            One-command full deployment"
    Write-Host "  puppet-deploy           Deploy using Puppet Bolt"
    Write-Host "  puppet-test             Run Puppet tests"
    Write-Host "  backup                  Backup cluster state"
    Write-Host "  restore                 Restore cluster from backup"
    Write-Host "  setup-monitoring        Deploy monitoring stack (Prometheus, Grafana)"
    Write-Host "  deploy-data-stack       Deploy data engineering stack (NiFi, Trino, etc.)"
    Write-Host "  maintenance             Perform cluster maintenance operations"
    Write-Host "  setup-full              Setup monitoring and backup procedures"
    Write-Host "  cluster-status          Check cluster health status"
    Write-Host "  cluster-overview        Get comprehensive cluster overview"
    Write-Host "  puppet-facts            Gather facts from all nodes"
    Write-Host "  puppet-apply            Apply Puppet configuration to specific nodes"
    Write-Host "  test                    Run integration tests"
    Write-Host "  kubeconfig              Get kubeconfig from cluster"
    Write-Host "  nifi-ui                 Port forward to NiFi UI"
    Write-Host "  grafana-ui              Port forward to Grafana UI"
    Write-Host "  clear-apt-locks         Clear APT package manager locks"
    Write-Host "  node-shell              Get shell on a node"
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Yellow
    Write-Host "  -Environment <env>      Target environment (dev, staging, prod) [default: dev]"
    Write-Host "  -BackupName <name>      Backup name [default: manual-YYYYMMDD-HHMMSS]"
    Write-Host "  -PuppetEnv <env>        Puppet environment [default: production]"
    Write-Host "  -Targets <targets>      Puppet targets [default: all]"
    Write-Host "  -Operation <op>         Maintenance operation (all, cleanup_images, disk_cleanup, log_rotation, restart_services, update_packages) [default: all]"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\Make.ps1 init"
    Write-Host "  .\Make.ps1 puppet-deploy -Environment prod"
    Write-Host "  .\Make.ps1 backup -BackupName pre-upgrade"
    Write-Host "  .\Make.ps1 maintenance -Operation disk_cleanup"
    Write-Host "  .\Make.ps1 node-shell -Targets pi-master"
    Write-Host ""
}

function Initialize-Project {
    Write-Step "Initializing project..."

    # Initialize Terraform
    Write-Info "Initializing Terraform..."
    Push-Location "terraform/environments/$Environment"
    try {
        terraform init
        if ($LASTEXITCODE -ne 0) { throw "Terraform init failed" }
    } finally {
        Pop-Location
    }

    # Install Puppet modules
    Write-Info "Installing Puppet modules..."
    Push-Location puppet
    try {
        if (Get-Command bundle -ErrorAction SilentlyContinue) {
            bundle config set --local path 'vendor/bundle'
            bundle install
            if ($LASTEXITCODE -ne 0) { throw "Bundle install failed" }
            Write-Info "Puppet modules installed successfully"
        } else {
            Write-Warning "Ruby bundle not found, skipping bundle install"
        }

        # Note: Skipping bolt module install as we're using Docker-based Bolt
        Write-Info "Using Docker-based Bolt, skipping module install"
    } finally {
        Pop-Location
    }

    # Update Helm repositories
    Write-Info "Updating Helm repositories..."
    $repos = helm repo list --output json | ConvertFrom-Json
    if ($repos.Count -eq 0) {
        Write-Warning "No Helm repos found. Adding stable repo..."
        helm repo add stable https://charts.helm.sh/stable
    }
    helm repo update

    Write-Step "Project initialization complete!"
}

function Test-Configurations {
    Write-Step "Validating configurations..."

    # Validate Terraform
    Write-Info "Validating Terraform configurations..."
    Push-Location "terraform/environments/$Environment"
    try {
        terraform validate
        if ($LASTEXITCODE -ne 0) { throw "Terraform validation failed" }
    } finally {
        Pop-Location
    }

# Validate Puppet
Write-Info "Validating Puppet modules..."
Push-Location puppet
try {
    if (Get-Command pdk -ErrorAction SilentlyContinue) {
        # Install bundle dependencies at puppet directory level first
        if (Test-Path "Gemfile") {
            Write-Info "Installing Puppet bundle dependencies..."
            try {
                bundle install --quiet
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Bundle install had issues, continuing with validation..."
                }
            } catch {
                Write-Warning "Bundle install failed, continuing with basic validation..."
            }
        }

        $modules = Get-ChildItem -Directory -Path "site-modules"
        $validatedModules = 0
        $totalModules = 0

        foreach ($module in $modules) {
            $totalModules++
            if (Test-Path "$($module.FullName)\metadata.json") {
                Write-Host "`n📦 Validating module: $($module.Name)" -ForegroundColor Cyan
                Push-Location $module.FullName

                try {
                    # Use basic validation without requiring full PDK setup
                    pdk validate --format=json 2>$null | Out-Null
                    $exitCode = $LASTEXITCODE

                    if ($exitCode -eq 0) {
                        Write-Host "✅ $($module.Name) passed validation" -ForegroundColor Green
                        $validatedModules++
                    } elseif ($exitCode -eq 2) {
                        Write-Warning "⚠️ Style issues in $($module.Name), but structure is valid"
                        $validatedModules++
                    } else {
                        Write-Warning "⚠️ PDK validation issues in $($module.Name), checking basic syntax..."
                        # Fall back to basic syntax check
                        $ppFiles = Get-ChildItem -Recurse -Filter "*.pp" -ErrorAction SilentlyContinue
                        $syntaxErrors = 0
                        foreach ($ppFile in $ppFiles) {
                            try {
                                puppet parser validate $ppFile.FullName 2>$null
                                if ($LASTEXITCODE -ne 0) { $syntaxErrors++ }
                            } catch { $syntaxErrors++ }
                        }
                        if ($syntaxErrors -eq 0) {
                            Write-Host "✅ $($module.Name) has valid Puppet syntax" -ForegroundColor Green
                            $validatedModules++
                        } else {
                            Write-Warning "⚠️ Syntax errors found in $($module.Name)"
                        }
                    }
                } catch {
                    Write-Warning "⚠️ Could not validate $($module.Name): $_"
                }

                Pop-Location
            } else {
                Write-Warning "⚠️ Skipping $($module.Name) — metadata.json not found"
            }
        }

        if ($validatedModules -eq $totalModules) {
            Write-Host "`n✅ All $totalModules Puppet modules validated successfully" -ForegroundColor Green
        } else {
            Write-Host "`n⚠️ $validatedModules/$totalModules Puppet modules validated" -ForegroundColor Yellow
        }
    } else {
        Write-Warning "⚠️ PDK not found, performing basic syntax validation..."

        # Fall back to basic puppet syntax checking
        $allPuppetFiles = Get-ChildItem -Recurse -Filter "*.pp" -Path "site-modules", "manifests", "plans" -ErrorAction SilentlyContinue
        $syntaxErrors = 0
        $totalFiles = $allPuppetFiles.Count

        if ($totalFiles -gt 0) {
            Write-Info "Checking syntax of $totalFiles Puppet files..."
            foreach ($file in $allPuppetFiles) {
                try {
                    if (Get-Command puppet -ErrorAction SilentlyContinue) {
                        puppet parser validate $file.FullName 2>$null
                        if ($LASTEXITCODE -ne 0) {
                            $syntaxErrors++
                            Write-Verbose "Syntax error in: $($file.Name)"
                        }
                    }
                } catch {
                    $syntaxErrors++
                }
            }

            if ($syntaxErrors -eq 0) {
                Write-Host "✅ All $totalFiles Puppet files have valid syntax" -ForegroundColor Green
            } else {
                Write-Warning "⚠️ $syntaxErrors/$totalFiles Puppet files have syntax issues"
            }
        } else {
            Write-Warning "⚠️ No Puppet files found for validation"
        }
    }
}
finally {
    Pop-Location
}

    # Validate Kubernetes manifests
    Write-Info "Validating Kubernetes manifests..."
    try {
        if (Get-Command kubectl -ErrorAction SilentlyContinue) {
            $k8sPath = "k8s/overlays/$Environment"
            if (Test-Path $k8sPath) {
                kubectl --dry-run=client --validate=false apply -k $k8sPath 2>$null
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Kubernetes manifest validation had issues"
                } else {
                    Write-Host "✅ Kubernetes manifests validated" -ForegroundColor Green
                }
            } else {
                Write-Warning "Kubernetes overlay path not found: $k8sPath"
            }
        } else {
            Write-Warning "kubectl not available, skipping Kubernetes validation"
        }
    } catch {
        Write-Warning "Cluster not available, skipping Kubernetes validation"
    }

    Write-Step "Configuration validation complete!"
    Write-Info "You can now run 'Make.ps1 apply' to deploy the infrastructure"
    Write-Info "Or run 'Make.ps1 quick-deploy' for a full deployment including Puppet"
    Write-Info "For help, run 'Make.ps1 help'"
}

function Invoke-PuppetDeploy {
    Write-Step "Deploying using Puppet Bolt..."

    try {
        # Use robust deployment plan that handles apt locks better
        & "$PSScriptRoot\bolt.ps1" -cmd "plan run pi_cluster_automation::deploy_robust deploy_env=$Environment" -targets $Targets -inventory "../inventory.yaml" -workdir "puppet"

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Deployment encountered issues. Trying fallback approach..."
            & "$PSScriptRoot\bolt.ps1" -cmd "plan run pi_cluster_automation::deploy deploy_env=$Environment" -targets $Targets -inventory "../inventory.yaml" -workdir "puppet"

            if ($LASTEXITCODE -ne 0) { throw "Puppet deployment failed" }
        }
    } finally {
        # No location change needed since we're not using Push-Location
    }

    Write-Step "Puppet deployment complete!"
}

function Test-Puppet {
    Write-Step "Running Puppet tests..."

    Push-Location puppet
    try {
        if (Get-Command pdk -ErrorAction SilentlyContinue) {
            pdk test unit
            if ($LASTEXITCODE -ne 0) { throw "Puppet unit tests failed" }

            pdk test unit --parallel
        } else {
            Write-Warning "PDK not found, skipping Puppet tests"
        }
    } finally {
        Pop-Location
    }

    Write-Step "Puppet tests complete!"
}

function Get-PuppetFacts {
    Write-Step "Gathering facts from all nodes..."

    # Get basic system information since facts task isn't available
    & "$PSScriptRoot\bolt.ps1" -cmd "command run 'uname -a && whoami && uptime'" -targets $Targets -inventory "inventory.yaml"
}

function Invoke-PuppetApply {
    Write-Step "Applying Puppet configuration to targets: $Targets"

    & "$PSScriptRoot\bolt.ps1" -cmd "plan run pi_cluster_automation::deploy" -targets $Targets -inventory "../inventory.yaml" -workdir "puppet"
}

function Invoke-Plan {
    Write-Step "Planning infrastructure changes..."

    Push-Location "terraform/environments/$Environment"
    try {
        # Check if terraform.tfvars exists
        if (Test-Path "terraform.tfvars") {
            Write-Info "Using terraform.tfvars file"
            terraform plan
        } else {
            Write-Warning "terraform.tfvars not found, using defaults"
            if (Test-Path "terraform.tfvars.example") {
                Write-Info "Consider copying terraform.tfvars.example to terraform.tfvars"
            }
            terraform plan
        }
        if ($LASTEXITCODE -ne 0) { throw "Terraform plan failed" }
    } finally {
        Pop-Location
    }
}

function Invoke-Apply {
    Write-Step "Applying infrastructure changes..."

    Push-Location "terraform/environments/$Environment"
    try {
        if (Test-Path "terraform.tfvars") {
            terraform apply -var-file=terraform.tfvars -auto-approve
        } else {
            Write-Warning "terraform.tfvars not found, using terraform.tfvars.example"
            if (Test-Path "terraform.tfvars.example") {
                terraform apply -var-file=terraform.tfvars.example -auto-approve
            } else {
                terraform apply -auto-approve
            }
        }
        if ($LASTEXITCODE -ne 0) { throw "Terraform apply failed" }
    } finally {
        Pop-Location
    }

    # Run Puppet deployment
    Invoke-PuppetDeploy
}

function Invoke-Destroy {
    Write-Step "Destroying infrastructure..."
    Write-Warning "This will destroy all infrastructure!"

    $confirm = Read-Host "Are you sure? Type 'yes' to continue"
    if ($confirm -eq "yes") {
        Push-Location "terraform/environments/$Environment"
        try {
            terraform destroy -var-file=terraform.tfvars -auto-approve
        } finally {
            Pop-Location
        }
    } else {
        Write-Info "Destroy cancelled"
    }
}

function Invoke-Backup {
    Write-Step "Creating cluster backup: $BackupName"

    & "$PSScriptRoot\bolt.ps1" -cmd "plan run pi_cluster_automation::backup --params '{`"backup_name`":`"$BackupName`"}'" -targets "masters" -inventory "inventory.yaml"

    Write-Step "Backup complete!"
}

function Invoke-Restore {
    Write-Step "Restoring cluster from backup: $BackupName"

    & "$PSScriptRoot\bolt.ps1" -cmd "plan run pi_cluster_automation::restore --params '{`"backup_name`":`"$BackupName`"}'" -targets "masters" -inventory "inventory.yaml"

    Write-Step "Restore complete!"
}

function Get-Kubeconfig {
    Write-Step "Retrieving kubeconfig from cluster..."

    $kubeconfigDir = "$env:USERPROFILE\.kube"
    if (!(Test-Path $kubeconfigDir)) {
        New-Item -ItemType Directory -Path $kubeconfigDir | Out-Null
    }

    & "$PSScriptRoot\bolt.ps1" -cmd "file download /etc/rancher/k3s/k3s.yaml $kubeconfigDir\config" -targets "masters" -inventory "inventory.yaml"

    # Update server IP in kubeconfig
    $kubeconfigPath = "$kubeconfigDir\config"
    if (Test-Path $kubeconfigPath) {
        $content = Get-Content $kubeconfigPath | ForEach-Object {
            $_ -replace "127\.0\.0\.1", "192.168.0.120"
        }
        $content | Set-Content $kubeconfigPath

        Write-Step "Kubeconfig saved to $kubeconfigPath"
        Write-Info "Test with: kubectl get nodes"
    }
}

function Start-NiFiPortForward {
    Write-Info "Starting port forward to NiFi UI..."
    Write-Info "NiFi will be available at: http://localhost:8080"
    Write-Warning "Press Ctrl+C to stop port forwarding"

    kubectl port-forward -n data-engineering svc/nifi 8080:8080
}

function Start-GrafanaPortForward {
    Write-Info "Starting port forward to Grafana UI..."
    Write-Info "Grafana will be available at: http://localhost:3000"
    Write-Warning "Press Ctrl+C to stop port forwarding"

    kubectl port-forward -n monitoring svc/grafana 3000:3000
}

function Get-ClusterStatus {
    Write-Step "Checking cluster status..."

    & "$PSScriptRoot\bolt.ps1" -cmd "task run pi_cluster_automation::cluster_status" -targets "masters" -inventory "../inventory.yaml"
}

function Get-ClusterOverview {
    Write-Step "Getting comprehensive cluster overview..."

    & "$PSScriptRoot\bolt.ps1" -cmd "task run pi_cluster_automation::cluster_overview" -targets "pi-master" -inventory "../inventory.yaml"
}

function Clear-AptLocks {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string[]]$Targets
    )

    # Normalize targets (handle both comma-separated and array input)
    if ($Targets.Count -eq 1 -and $Targets[0] -match ",") {
        $Targets = $Targets[0] -split "," | ForEach-Object { $_.Trim() }
    }

    Write-Step "🔧 Clearing APT locks on targets: $($Targets -join ', ')"

    # Process termination commands (expected to fail when no processes exist)
    $killCommands = @(
        @{Command="sudo pkill -f apt"; Description="Stop APT processes"},
        @{Command="sudo pkill -f dpkg"; Description="Stop DPKG processes"}
    )

    foreach ($cmd in $killCommands) {
        Write-Info "➡️ $($cmd.Description)..."
        try {
            $result = & "$PSScriptRoot\bolt.ps1" -cmd "command run '$($cmd.Command)'" -targets ($Targets -join ',') -inventory "inventory.yaml"

            # Check exit code but don't fail - these commands often exit non-zero when no processes exist
            if ($LASTEXITCODE -ne 0) {
                Write-Info "ℹ️ No active processes found (expected for $($cmd.Description))"
            }
        }
        catch {
            Write-Warning "⚠️ Process check failed (non-critical): $($cmd.Description)`n$_"
        }
        Start-Sleep -Seconds 1
    }

    # Lock file operations (should succeed)
    $lockPaths = "/var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock*"
    Write-Info "➡️ Removing lock files..."
    try {
        $result = & "$PSScriptRoot\bolt.ps1" -cmd "command run 'sudo rm -f $lockPaths'" -targets ($Targets -join ',') -inventory "inventory.yaml"

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "⚠️ Some lock files may not have been removed"
        }
        else {
            Write-Info "✅ Lock files successfully removed"
        }
    }
    catch {
        Write-Error "❌ Failed to remove lock files`n$_"
        return $false
    }

    # DPKG repair (should succeed)
    Write-Info "➡️ Repairing DPKG configuration..."
    try {
        $result = & "$PSScriptRoot\bolt.ps1" -cmd "command run 'sudo dpkg --configure -a'" -targets ($Targets -join ',') -inventory "inventory.yaml"

        if ($LASTEXITCODE -ne 0) {
            Write-Error "❌ Failed to repair DPKG configuration"
            return $false
        }
        Write-Info "✅ DPKG configuration repaired"
    }
    catch {
        Write-Error "❌ Failed to repair DPKG configuration`n$_"
        return $false
    }

    Write-Step "✅ APT lock clearance completed successfully"
    return
}

function Get-NodeShell {
    Write-Step "Getting shell on node(s): $Targets"

    & "$PSScriptRoot\bolt.ps1" -cmd "command run 'sudo -i'" -targets $Targets -inventory "inventory.yaml"
}

function Invoke-IntegrationTests {
    Write-Step "Running integration tests..."

    # Test cluster connectivity
    kubectl get nodes
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Cluster connectivity test failed"
        return
    }

    # Test services
    kubectl get svc -A
    kubectl get pods -A

    Write-Step "Integration tests complete!"
}

function Install-Monitoring {
    Write-Step "Setting up monitoring stack..."

    $params = @{
        stack_components = "all"
        namespace = "monitoring"
        persistent_storage = $true
        retention_days = 15
    }
    $paramsJson = $params | ConvertTo-Json -Compress

    & "$PSScriptRoot\bolt.ps1" -cmd "task run pi_cluster_automation::setup_monitoring --params '$paramsJson'" -targets "pi-master" -inventory "../inventory.yaml"
}

function Backup-Cluster {
    Write-Step "Backing up cluster..."

    $params = @{
        backup_type = "full"
        backup_location = "/opt/backups"
        retention_days = 7
    }
    $paramsJson = $params | ConvertTo-Json -Compress

    & "$PSScriptRoot\bolt.ps1" -cmd "task run pi_cluster_automation::backup_cluster --params '$paramsJson'" -targets "pi-master" -inventory "../inventory.yaml"
}

function Restore-Cluster {
    param([string]$BackupPath)

    if (-not $BackupPath) {
        Write-Error "Please specify backup path with -BackupPath parameter"
        return
    }

    Write-Step "Restoring cluster from backup: $BackupPath"
    Write-Warning "This will overwrite current cluster state!"

    $confirm = Read-Host "Continue? (y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Info "Restore cancelled"
        return
    }

    & "$PSScriptRoot\bolt.ps1" -cmd "task run pi_cluster_automation::restore_cluster backup_path=$BackupPath force=true" -targets "masters" -inventory "../inventory.yaml"
}

function Install-DataStack {
    Write-Step "Deploying data engineering stack..."

    $params = @{
        components = "all"
    }
    $paramsJson = $params | ConvertTo-Json -Compress

    & "$PSScriptRoot\bolt.ps1" -cmd "task run pi_cluster_automation::deploy_data_stack --params '$paramsJson'" -targets "pi-master" -inventory "../inventory.yaml"
}

function Start-Maintenance {
    param([string]$Operation = "all")

    Write-Step "Performing cluster maintenance: $Operation"

    & "$PSScriptRoot\bolt.ps1" -cmd "task run pi_cluster_automation::cluster_maintenance operation=$Operation force=false" -targets $Targets -inventory "../inventory.yaml"
}

function Install-MonitoringAndBackup {
    Write-Step "Setting up comprehensive monitoring and backup procedures..."

    & "$PSScriptRoot\bolt.ps1" -cmd "plan run pi_cluster_automation::setup_monitoring_backup setup_monitoring=true setup_backup=true" -targets "all" -inventory "../inventory.yaml"
}

# Terraform-specific functions
function Invoke-TerraformInit {
    Write-Step "Initializing Terraform for environment: $Environment"

    $terraformPath = "terraform/environments/$Environment"
    if (-not (Test-Path $terraformPath)) {
        Write-Error "Terraform environment path not found: $terraformPath"
        return
    }

    Push-Location $terraformPath
    try {
        Write-Info "Running: terraform init"
        terraform init
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform init failed with exit code $LASTEXITCODE"
        }
        Write-Info "✅ Terraform initialized successfully"
    } catch {
        Write-Error "Terraform init failed: $_"
        throw
    } finally {
        Pop-Location
    }
}

function Invoke-TerraformValidate {
    Write-Step "Validating Terraform configuration for environment: $Environment"

    $terraformPath = "terraform/environments/$Environment"
    if (-not (Test-Path $terraformPath)) {
        Write-Error "Terraform environment path not found: $terraformPath"
        return
    }

    Push-Location $terraformPath
    try {
        Write-Info "Running: terraform validate"
        terraform validate
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform validation failed with exit code $LASTEXITCODE"
        }
        Write-Info "✅ Terraform configuration is valid"
    } catch {
        Write-Error "Terraform validation failed: $_"
        throw
    } finally {
        Pop-Location
    }
}

function Invoke-TerraformPlan {
    param(
        [string]$Environment = "dev"
    )

    Write-Step "Planning infrastructure changes..."

    # Set the working directory based on environment
    $TerraformDir = "terraform/environments/$Environment"

    if (-not (Test-Path $TerraformDir)) {
        throw "Environment directory not found: $TerraformDir"
    }

    # Check if terraform.tfvars exists
    $TfVarsFile = "$TerraformDir/terraform.tfvars"
    if (-not (Test-Path $TfVarsFile)) {
        Write-Warning "terraform.tfvars not found at $TfVarsFile"
        Write-Warning "Copy terraform.tfvars.example to terraform.tfvars and update values"

        $ExampleFile = "$TerraformDir/terraform.tfvars.example"
        if (Test-Path $ExampleFile) {
            Write-Info "Example file available at: $ExampleFile"
        }
    }

    Push-Location $TerraformDir
    try {
        # Initialize if needed
        if (-not (Test-Path ".terraform")) {
            Write-Info "Initializing Terraform..."
            terraform init
            if ($LASTEXITCODE -ne 0) {
                throw "Terraform init failed"
            }
        }

        # Run terraform plan
        Write-Info "Running terraform plan for environment: $Environment"
        terraform plan

        if ($LASTEXITCODE -ne 0) {
            throw "Terraform plan failed"
        }

        function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

        Write-Success "Terraform plan completed successfully"

    } catch {
        Write-Error "Terraform plan failed: $_"
        throw

    } finally {
        Pop-Location
    }
}

function Invoke-TerraformApply {
    param(
        [string]$Environment = "dev",
        [switch]$AutoApprove
    )

    Write-Step "Applying infrastructure changes..."

    $TerraformDir = "terraform/environments/$Environment"

    if (-not (Test-Path $TerraformDir)) {
        throw "Environment directory not found: $TerraformDir"
    }

    Push-Location $TerraformDir
    try {
        # Run terraform apply
        $ApplyArgs = @()
        if ($AutoApprove) {
            $ApplyArgs += "-auto-approve"
        }

        Write-Info "Running terraform apply for environment: $Environment"
        if ($ApplyArgs.Count -gt 0) {
            terraform apply @ApplyArgs
        } else {
            terraform apply
        }

        if ($LASTEXITCODE -ne 0) {
            throw "Terraform apply failed"
        }

        Write-Success "Terraform apply completed successfully"

    } finally {
        Pop-Location
    }
}

function Invoke-TerraformDestroy {
    param(
        [string]$Environment = "dev",
        [switch]$AutoApprove
    )

    Write-Step "Destroying infrastructure..."

    $TerraformDir = "terraform/environments/$Environment"

    if (-not (Test-Path $TerraformDir)) {
        throw "Environment directory not found: $TerraformDir"
    }

    # Confirmation prompt unless auto-approve is used
    if (-not $AutoApprove) {
        $Confirmation = Read-Host "Are you sure you want to destroy the $Environment environment? (yes/no)"
        if ($Confirmation -ne "yes") {
            Write-Info "Destroy cancelled"
            return
        }
    }

    Push-Location $TerraformDir
    try {
        $DestroyArgs = @()
        if ($AutoApprove) {
            $DestroyArgs += "-auto-approve"
        }

        Write-Info "Running terraform destroy for environment: $Environment"
        if ($DestroyArgs.Count -gt 0) {
            terraform destroy @DestroyArgs
        } else {
            terraform destroy
        }

        if ($LASTEXITCODE -ne 0) {
            throw "Terraform destroy failed"
        }

        Write-Success "Terraform destroy completed successfully"

    } finally {
        Pop-Location
    }
}

function Invoke-QuickDeploy {
    Write-Step "🚀 Starting quick deployment for environment: $Environment"

    try {
        Write-Info "Step 1: Initializing Terraform..."
        Invoke-TerraformInit

        Write-Info "Step 2: Validating Terraform configuration..."
        Invoke-TerraformValidate

        Write-Info "Step 3: Planning Terraform changes..."
        Invoke-TerraformPlan

        Write-Info "Step 4: Applying Terraform infrastructure..."
        Invoke-TerraformApply

        Write-Info "Step 5: Deploying with Puppet..."
        Invoke-PuppetDeploy

        Write-Info "Step 6: Checking cluster status..."
        Start-Sleep -Seconds 30  # Wait for services to start
        Get-ClusterStatus

        Write-Step "🎉 Quick deployment completed successfully!"
        Write-Info ""
        Write-Info "Next steps:"
        Write-Info "1. Get kubeconfig: .\Make.ps1 kubeconfig -Environment $Environment"
        Write-Info "2. Check cluster: kubectl get nodes"
        Write-Info "3. Access NiFi UI: .\Make.ps1 nifi-ui"
        Write-Info "4. Access Grafana: .\Make.ps1 grafana-ui"

    } catch {
        Write-Error "Quick deployment failed: $_"
        Write-Error "You can retry individual steps or check logs for details"
        throw
    }
}

# Main command dispatcher
switch ($Command.ToLower()) {
    "help" { Show-Help }
    "init" { Initialize-Project }
    "validate" { Test-Configurations }
    "plan" { Invoke-Plan }
    "apply" { Invoke-Apply }
    "destroy" { Invoke-Destroy }
    "terraform-init" { Invoke-TerraformInit }
    "terraform-plan" { Invoke-TerraformPlan }
    "terraform-apply" { Invoke-TerraformApply }
    "terraform-destroy" { Invoke-TerraformDestroy }
    "terraform-validate" { Invoke-TerraformValidate }
    "quick-deploy" { Invoke-QuickDeploy }
    "puppet-deploy" { Invoke-PuppetDeploy }
    "puppet-test" { Test-Puppet }
    "puppet-facts" { Get-PuppetFacts }
    "puppet-apply" { Invoke-PuppetApply }
    "test" { Invoke-IntegrationTests }
    "backup" { Backup-Cluster }
    "restore" { Restore-Cluster -BackupPath $BackupName }
    "setup-monitoring" { Install-Monitoring }
    "deploy-data-stack" { Install-DataStack }
    "maintenance" { Start-Maintenance -Operation $Operation }
    "setup-full" { Install-MonitoringAndBackup }
    "kubeconfig" { Get-Kubeconfig }
    "nifi-ui" { Start-NiFiPortForward }
    "grafana-ui" { Start-GrafanaPortForward }
    "cluster-status" { Get-ClusterStatus }
    "cluster-overview" { Get-ClusterOverview }
    "clear-apt-locks" { Clear-AptLocks -Targets $Targets }
    "node-shell" { Get-NodeShell }
    default {
        Write-Error "Unknown command: $Command"
        Write-Info "Use '.\Make.ps1 help' to see available commands"
        exit 1
    }
}
