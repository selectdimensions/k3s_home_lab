# PowerShell equivalent of Makefile for Windows users
# Usage: .\Make.ps1 <command>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$Command = "help",
    
    [string]$Environment = "dev",
    [string]$BackupName = "manual-$(Get-Date -Format 'yyyyMMdd-HHmmss')",
    [string]$PuppetEnv = "production",
    [string]$Targets = "all"
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
    Write-Host ""
    Write-Host "  help                    Show this help message"
    Write-Host "  init                    Initialize the project"
    Write-Host "  validate                Validate configurations"
    Write-Host "  plan                    Plan infrastructure changes"
    Write-Host "  apply                   Apply infrastructure changes and run Puppet"
    Write-Host "  destroy                 Destroy infrastructure"
    Write-Host "  puppet-deploy           Deploy using Puppet Bolt"
    Write-Host "  puppet-test             Run Puppet tests"
    Write-Host "  puppet-facts            Gather facts from all nodes"
    Write-Host "  puppet-apply            Apply Puppet configuration to specific nodes"
    Write-Host "  test                    Run integration tests"
    Write-Host "  backup                  Create cluster backup"
    Write-Host "  restore                 Restore from backup"
    Write-Host "  kubeconfig              Get kubeconfig from cluster"
    Write-Host "  nifi-ui                 Port forward to NiFi UI"
    Write-Host "  grafana-ui              Port forward to Grafana UI"
    Write-Host "  cluster-status          Check cluster status"
    Write-Host "  node-shell              Get shell on a node"
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Yellow
    Write-Host "  -Environment <env>      Target environment (dev, staging, prod) [default: dev]"
    Write-Host "  -BackupName <name>      Backup name [default: manual-YYYYMMDD-HHMMSS]"
    Write-Host "  -PuppetEnv <env>        Puppet environment [default: production]"
    Write-Host "  -Targets <targets>      Puppet targets [default: all]"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\Make.ps1 init"
    Write-Host "  .\Make.ps1 puppet-deploy -Environment prod"
    Write-Host "  .\Make.ps1 backup -BackupName pre-upgrade"
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
            bundle install
        } else {
            Write-Warning "Ruby bundle not found, skipping bundle install"
        }
        
        bolt module install
        if ($LASTEXITCODE -ne 0) { throw "Bolt module install failed" }
    } finally {
        Pop-Location
    }
    
    # Update Helm repositories
    Write-Info "Updating Helm repositories..."
    helm repo update
    
    Write-Step "Project initialization complete!"
}

function Test-Configurations {
    Write-Step "Validating configurations..."
    
    # Validate Terraform
    Write-Info "Validating Terraform..."
    Push-Location "terraform/environments/$Environment"
    try {
        terraform validate
        if ($LASTEXITCODE -ne 0) { throw "Terraform validation failed" }
    } finally {
        Pop-Location
    }
    
    # Validate Puppet
    Write-Info "Validating Puppet..."
    Push-Location puppet
    try {
        if (Get-Command pdk -ErrorAction SilentlyContinue) {
            pdk validate
            if ($LASTEXITCODE -ne 0) { throw "Puppet validation failed" }
        } else {
            Write-Warning "PDK not found, skipping Puppet validation"
        }
        
        bolt plan show
        if ($LASTEXITCODE -ne 0) { throw "Bolt plan validation failed" }
    } finally {
        Pop-Location
    }
    
    # Validate Kubernetes manifests
    Write-Info "Validating Kubernetes manifests..."
    kubectl --dry-run=client apply -k "k8s/overlays/$Environment"
    if ($LASTEXITCODE -ne 0) { throw "Kubernetes manifest validation failed" }
    
    Write-Step "All configurations are valid!"
}

function Invoke-PuppetDeploy {
    Write-Step "Deploying using Puppet Bolt..."
    
    Push-Location puppet
    try {
        bolt plan run pi_cluster_automation::deploy `
            --inventoryfile ../inventory.yaml `
            environment=$Environment `
            --run-as root
        
        if ($LASTEXITCODE -ne 0) { throw "Puppet deployment failed" }
    } finally {
        Pop-Location
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
    
    bolt task run facts --targets all --inventoryfile inventory.yaml
    
    Write-Step "Fact gathering complete!"
}

function Invoke-PuppetApply {
    Write-Step "Applying Puppet configuration to nodes..."
    
    bolt apply puppet/manifests/site.pp `
        --targets $Targets `
        --inventoryfile inventory.yaml `
        --hiera-config puppet/hiera.yaml
    
    if ($LASTEXITCODE -eq 0) {
        Write-Step "Puppet apply complete!"
    } else {
        Write-Error "Puppet apply failed!"
    }
}

function Invoke-Plan {
    Write-Step "Planning infrastructure changes..."
    
    Push-Location "terraform/environments/$Environment"
    try {
        terraform plan -var-file=terraform.tfvars
    } finally {
        Pop-Location
    }
}

function Invoke-Apply {
    Write-Step "Applying infrastructure changes..."
    
    Push-Location "terraform/environments/$Environment"
    try {
        terraform apply -var-file=terraform.tfvars -auto-approve
        if ($LASTEXITCODE -ne 0) { throw "Terraform apply failed" }
    } finally {
        Pop-Location
    }
    
    # Run Puppet deployment
    Invoke-PuppetDeploy
}

function Invoke-Destroy {
    Write-Warning "This will destroy all infrastructure in $Environment environment!"
    $confirmation = Read-Host "Are you sure? Type 'yes' to confirm"
    
    if ($confirmation -eq "yes") {
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
    
    bolt plan run pi_cluster_automation::backup `
        backup_name=$BackupName `
        --targets masters `
        --inventoryfile inventory.yaml
    
    Write-Step "Backup complete!"
}

function Invoke-Restore {
    Write-Step "Restoring cluster from backup: $BackupName"
    
    bolt plan run pi_cluster_automation::restore `
        backup_name=$BackupName `
        --targets masters `
        --inventoryfile inventory.yaml
    
    Write-Step "Restore complete!"
}

function Get-Kubeconfig {
    Write-Step "Retrieving kubeconfig from cluster..."
    
    $kubeconfigDir = "$env:USERPROFILE\.kube"
    if (!(Test-Path $kubeconfigDir)) {
        New-Item -ItemType Directory -Path $kubeconfigDir | Out-Null
    }
    
    bolt file download /etc/rancher/k3s/k3s.yaml "$kubeconfigDir\config" `
        --targets masters `
        --inventoryfile inventory.yaml
    
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
    
    kubectl port-forward -n data-platform svc/nifi 8080:8080
}

function Start-GrafanaPortForward {
    Write-Info "Starting port forward to Grafana UI..."
    Write-Info "Grafana will be available at: http://localhost:3000"
    Write-Warning "Press Ctrl+C to stop port forwarding"
    
    kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
}

function Get-ClusterStatus {
    Write-Step "Checking cluster status..."
    
    bolt task run pi_cluster_automation::cluster_status `
        --targets masters `
        --inventoryfile inventory.yaml
}

function Get-NodeShell {
    Write-Step "Getting shell on node(s): $Targets"
    
    bolt command run 'sudo -i' --targets $Targets --inventoryfile inventory.yaml
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

# Main command dispatcher
switch ($Command.ToLower()) {
    "help" { Show-Help }
    "init" { Initialize-Project }
    "validate" { Test-Configurations }
    "plan" { Invoke-Plan }
    "apply" { Invoke-Apply }
    "destroy" { Invoke-Destroy }
    "puppet-deploy" { Invoke-PuppetDeploy }
    "puppet-test" { Test-Puppet }
    "puppet-facts" { Get-PuppetFacts }
    "puppet-apply" { Invoke-PuppetApply }
    "test" { Invoke-IntegrationTests }
    "backup" { Invoke-Backup }
    "restore" { Invoke-Restore }
    "kubeconfig" { Get-Kubeconfig }
    "nifi-ui" { Start-NiFiPortForward }
    "grafana-ui" { Start-GrafanaPortForward }
    "cluster-status" { Get-ClusterStatus }
    "node-shell" { Get-NodeShell }
    default {
        Write-Error "Unknown command: $Command"
        Write-Info "Use '.\Make.ps1 help' to see available commands"
        exit 1
    }
}