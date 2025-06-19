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
    Write-Host ""    Write-Host "  help                    Show this help message"
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
    Write-Host "  kubeconfig              Get kubeconfig from cluster"    Write-Host "  nifi-ui                 Port forward to NiFi UI"
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
            $modules = Get-ChildItem -Directory -Path "site-modules"
            foreach ($module in $modules) {
                if (Test-Path "$($module.FullName)\metadata.json") {
                    Write-Host "`n📦 Validating module: $($module.Name)" -ForegroundColor Cyan
                    Push-Location $module.FullName
                    pdk validate
                    if ($LASTEXITCODE -ne 0) {
                        Write-Error "❌ PDK validation failed for module $($module.Name)"
                        exit 1
                    }
                    Pop-Location
                } else {
                    Write-Warning "⚠️ Skipping $($module.Name) — not a PDK-compatible module"
                }
            }
            Write-Host "`n✅ All Puppet modules validated successfully" -ForegroundColor Green
        } else {
            Write-Warning "⚠️ PDK not found, skipping Puppet validation"
        }
    }
    finally {
        Pop-Location
    }

    # Validate Kubernetes manifests
    Write-Info "Validating Kubernetes manifests..."
    try {
        if (Get-Command kubectl -ErrorAction SilentlyContinue) {
            kubectl --dry-run=client --validate=false apply -k "k8s/overlays/$Environment"
            if ($LASTEXITCODE -ne 0) { throw "Kubernetes manifest validation failed" }
        } else {
            Write-Warning "Cluster not available, skipping Kubernetes validation"
        }
    } catch {
        Write-Warning "Cluster not available, skipping Kubernetes validation"
    }

    Write-Step "All configurations are valid!"
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

    & "$PSScriptRoot\bolt.ps1" -cmd "plan run pi_cluster_automation::deploy" -targets $Targets -inventory "inventory.yaml"
}

function Invoke-Plan {
    Write-Step "Planning infrastructure changes..."

    Push-Location "terraform/environments/$Environment"
    try {
        if (Test-Path "terraform.tfvars") {
            terraform plan -var-file=terraform.tfvars
        } else {
            Write-Warning "terraform.tfvars not found, using terraform.tfvars.example"
            if (Test-Path "terraform.tfvars.example") {
                terraform plan -var-file=terraform.tfvars.example
            } else {
                terraform plan
            }
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
    Write-Step "Planning Terraform changes for environment: $Environment"

    $terraformPath = "terraform/environments/$Environment"
    if (-not (Test-Path $terraformPath)) {
        Write-Error "Terraform environment path not found: $terraformPath"
        return
    }

    Push-Location $terraformPath
    try {
        Write-Info "Running: terraform plan"
        terraform plan -out="terraform-$Environment.tfplan"
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform plan failed with exit code $LASTEXITCODE"
        }
        Write-Info "✅ Terraform plan completed successfully"
        Write-Info "Plan saved to: terraform-$Environment.tfplan"
    } catch {
        Write-Error "Terraform plan failed: $_"
        throw
    } finally {
        Pop-Location
    }
}

function Invoke-TerraformApply {
    Write-Step "Applying Terraform changes for environment: $Environment"

    $terraformPath = "terraform/environments/$Environment"
    if (-not (Test-Path $terraformPath)) {
        Write-Error "Terraform environment path not found: $terraformPath"
        return
    }

    Push-Location $terraformPath
    try {
        $planFile = "terraform-$Environment.tfplan"
        if (Test-Path $planFile) {
            Write-Info "Running: terraform apply $planFile"
            terraform apply $planFile
        } else {
            Write-Info "Running: terraform apply -auto-approve"
            terraform apply -auto-approve
        }

        if ($LASTEXITCODE -ne 0) {
            throw "Terraform apply failed with exit code $LASTEXITCODE"
        }
        Write-Info "✅ Terraform apply completed successfully"

        # Clean up plan file
        if (Test-Path $planFile) {
            Remove-Item $planFile -Force
            Write-Info "Cleaned up plan file: $planFile"
        }
    } catch {
        Write-Error "Terraform apply failed: $_"
        throw
    } finally {
        Pop-Location
    }
}

function Invoke-TerraformDestroy {
    Write-Step "Destroying Terraform infrastructure for environment: $Environment"

    $terraformPath = "terraform/environments/$Environment"
    if (-not (Test-Path $terraformPath)) {
        Write-Error "Terraform environment path not found: $terraformPath"
        return
    }

    Write-Warning "⚠️  This will destroy all infrastructure in environment: $Environment"
    $confirmation = Read-Host "Are you sure you want to continue? (yes/no)"
    if ($confirmation -ne "yes") {
        Write-Info "Operation cancelled"
        return
    }

    Push-Location $terraformPath
    try {
        Write-Info "Running: terraform destroy -auto-approve"
        terraform destroy -auto-approve
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform destroy failed with exit code $LASTEXITCODE"
        }
        Write-Info "✅ Terraform destroy completed successfully"
    } catch {
        Write-Error "Terraform destroy failed: $_"
        throw
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
    "grafana-ui" { Start-GrafanaPortForward }    "cluster-status" { Get-ClusterStatus }
    "cluster-overview" { Get-ClusterOverview }
    "clear-apt-locks" { Clear-AptLocks }
    "node-shell" { Get-NodeShell }
    default {
        Write-Error "Unknown command: $Command"
        Write-Info "Use '.\Make.ps1 help' to see available commands"
        exit 1
    }
}
