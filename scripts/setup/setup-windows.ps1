# Windows setup script for k3s_home_lab
# This script installs the necessary tools to manage the Pi cluster from Windows

[CmdletBinding()]
param(
    [string]$PuppetServerIP = "192.168.0.120",
    [string]$Environment = "production",
    [switch]$Force
)

# Configuration
$CLUSTER_DOMAIN = "cluster.local"
$SSH_KEY_PATH = "$env:USERPROFILE\.ssh\keys\hobby\pi_k3s_cluster"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $Color
}

function Write-Step {
    param([string]$Message)
    Write-ColorOutput $Message "Green"
}

function Write-Info {
    param([string]$Message)
    Write-ColorOutput $Message "Cyan"
}

function Write-Warning {
    param([string]$Message)
    Write-ColorOutput $Message "Yellow"
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput $Message "Red"
}

# Step 1: Install Chocolatey if not present
function Install-Chocolatey {
    Write-Step "Checking for Chocolatey package manager..."
    
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Info "Installing Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        
        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Write-Step "Chocolatey installed successfully!"
    } else {
        Write-Info "Chocolatey is already installed"
    }
}

# Step 2: Install required tools
function Install-RequiredTools {
    Write-Step "Installing required tools..."
    
    $tools = @(
        "puppet-bolt",
        "terraform", 
        "kubernetes-helm",
        "git",
        "openssh",
        "jq"
    )
    
    foreach ($tool in $tools) {
        Write-Info "Installing $tool..."
        try {
            choco install $tool -y --force
        } catch {
            Write-Warning "Failed to install $tool via Chocolatey, trying alternative methods..."
            
            switch ($tool) {
                "puppet-bolt" {
                    # Download and install Puppet Bolt manually
                    $puppetUrl = "https://downloads.puppet.com/windows/puppet-tools/puppet-bolt-3.29.0-x64.msi"
                    $puppetFile = "$env:TEMP\puppet-bolt.msi"
                    Invoke-WebRequest -Uri $puppetUrl -OutFile $puppetFile
                    Start-Process msiexec.exe -ArgumentList "/i $puppetFile /qn /norestart" -Wait
                    Remove-Item $puppetFile
                }
                "terraform" {
                    # Download and install Terraform manually
                    $terraformUrl = "https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_windows_amd64.zip"
                    $terraformZip = "$env:TEMP\terraform.zip"
                    $terraformDir = "$env:PROGRAMFILES\Terraform"
                    
                    Invoke-WebRequest -Uri $terraformUrl -OutFile $terraformZip
                    Expand-Archive -Path $terraformZip -DestinationPath $terraformDir -Force
                    
                    # Add to PATH
                    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
                    if ($currentPath -notlike "*$terraformDir*") {
                        [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$terraformDir", "Machine")
                    }
                    
                    Remove-Item $terraformZip
                }
            }
        }
    }
    
    # Refresh PATH
    $env:PATH = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Step "All tools installed successfully!"
}

# Step 3: Set up SSH keys
function Setup-SSHKeys {
    Write-Step "Setting up SSH keys..."
    
    $sshKeyDir = Split-Path $SSH_KEY_PATH -Parent
    
    if (!(Test-Path $sshKeyDir)) {
        New-Item -ItemType Directory -Path $sshKeyDir -Force | Out-Null
    }
    
    if (!(Test-Path $SSH_KEY_PATH) -or $Force) {
        Write-Info "Generating SSH key pair..."
        ssh-keygen -t ed25519 -f $SSH_KEY_PATH -N '""' -C "pi-cluster-automation-windows"
        Write-Step "SSH key generated at $SSH_KEY_PATH"
    } else {
        Write-Info "SSH key already exists at $SSH_KEY_PATH"
    }
    
    # Display public key
    Write-Info "Add this public key to your Pi nodes:"
    Write-Host ""
    Write-Host (Get-Content "$SSH_KEY_PATH.pub") -ForegroundColor Yellow
    Write-Host ""
    Write-Warning "You need to add this key to ~/.ssh/authorized_keys on each Pi"
    Write-Warning "Or use the prepare-pi.ps1 script to automate this"
}

# Step 4: Update inventory for Windows paths
function Update-Inventory {
    Write-Step "Updating inventory.yaml for Windows paths..."
    
    $inventoryPath = "inventory.yaml"
    if (Test-Path $inventoryPath) {
        $content = Get-Content $inventoryPath | ForEach-Object {
            $_ -replace "~/.ssh/keys/hobby/pi_k3s_cluster", $SSH_KEY_PATH.Replace('\', '/')
        }
        $content | Set-Content $inventoryPath
        Write-Info "Updated inventory.yaml with Windows SSH key path"
    } else {
        Write-Warning "inventory.yaml not found. Please create it from the template"
    }
}

# Step 5: Test connectivity
function Test-Connectivity {
    Write-Step "Testing connectivity to cluster nodes..."
    
    if (!(Test-Path "inventory.yaml")) {
        Write-Error "inventory.yaml not found. Cannot test connectivity."
        return
    }
    
    try {
        Push-Location puppet
        bolt command run 'hostname' --targets all --inventoryfile ../inventory.yaml
        
        if ($LASTEXITCODE -eq 0) {
            Write-Step "Successfully connected to all nodes!"
        } else {
            Write-Warning "Failed to connect to some nodes. Check your SSH setup and Pi configuration."
        }
    } catch {
        Write-Error "Error testing connectivity: $($_.Exception.Message)"
    } finally {
        Pop-Location
    }
}

# Step 6: Install WSL for Linux compatibility (optional)
function Install-WSL {
    Write-Step "Checking for WSL (Windows Subsystem for Linux)..."
    
    if (Get-Command wsl -ErrorAction SilentlyContinue) {
        Write-Info "WSL is already available"
        return
    }
    
    Write-Info "Installing WSL for better Linux compatibility..."
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
        Write-Info "WSL installed. You may need to restart and install a Linux distribution."
        Write-Info "Recommended: wsl --install -d Ubuntu"
    } catch {
        Write-Warning "Could not install WSL automatically. You may need to enable it manually."
    }
}

# Step 7: Set up Windows hosts file for cluster DNS
function Setup-HostsFile {
    Write-Step "Setting up hosts file for cluster DNS..."
    
    $hostsFile = "$env:WINDIR\System32\drivers\etc\hosts"
    $hostsEntries = @(
        "$PuppetServerIP puppet.cluster.local puppet",
        "$PuppetServerIP pi-master.cluster.local pi-master",
        "192.168.0.121 pi-worker-1.cluster.local pi-worker-1",
        "192.168.0.122 pi-worker-2.cluster.local pi-worker-2", 
        "192.168.0.123 pi-worker-3.cluster.local pi-worker-3"
    )
    
    $currentHosts = Get-Content $hostsFile -ErrorAction SilentlyContinue
    $needsUpdate = $false
    
    foreach ($entry in $hostsEntries) {
        if ($currentHosts -notcontains $entry) {
            $needsUpdate = $true
            break
        }
    }
    
    if ($needsUpdate) {
        Write-Info "Adding cluster DNS entries to hosts file..."
        $hostsEntries | Add-Content $hostsFile
        Write-Step "Hosts file updated successfully!"
    } else {
        Write-Info "Hosts file already contains cluster DNS entries"
    }
}

# Main execution
function Main {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Blue
    Write-Host "   k3s_home_lab Windows Setup Script           " -ForegroundColor Blue  
    Write-Host "================================================" -ForegroundColor Blue
    Write-Host ""
    
    Write-Info "This script will set up your Windows machine to manage the Pi cluster"
    Write-Info "Steps to be performed:"
    Write-Host "  1. Install Chocolatey package manager"
    Write-Host "  2. Install required tools (Puppet Bolt, Terraform, Helm, etc.)"
    Write-Host "  3. Generate SSH keys for cluster access"
    Write-Host "  4. Update inventory.yaml for Windows paths"
    Write-Host "  5. Test connectivity to cluster nodes"
    Write-Host "  6. (Optional) Install WSL for Linux compatibility"
    Write-Host "  7. Update Windows hosts file for cluster DNS"
    Write-Host ""
    
    $confirmation = Read-Host "Continue with setup? (y/n)"
    if ($confirmation -notin @('y', 'Y', 'yes', 'Yes')) {
        Write-Info "Setup cancelled by user"
        exit 0
    }
    
    # Check if running as Administrator
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$currentUser
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (!$isAdmin) {
        Write-Warning "Some operations require Administrator privileges."
        Write-Warning "Please run this script as Administrator for full functionality."
        Write-Host ""
    }
    
    try {
        Install-Chocolatey
        Install-RequiredTools
        Setup-SSHKeys
        Update-Inventory
        
        if ($isAdmin) {
            Setup-HostsFile
        } else {
            Write-Warning "Skipping hosts file update (requires Administrator privileges)"
        }
        
        Test-Connectivity
        
        Write-Host ""
        Write-Step "Windows setup complete! 🎉"
        Write-Host ""
        Write-Info "Next steps:"
        Write-Host "  1. Ensure your Pi nodes are set up with Raspberry Pi OS"
        Write-Host "  2. Add the SSH public key to each Pi"
        Write-Host "  3. Run: .\scripts\prepare-pis.ps1 (if available) to automate Pi setup"
        Write-Host "  4. Run: make init (to initialize Terraform and Puppet modules)"
        Write-Host "  5. Run: make puppet-deploy (to deploy the cluster)"
        Write-Host ""
        Write-Info "SSH Public Key (add to Pi ~/.ssh/authorized_keys):"
        if (Test-Path "$SSH_KEY_PATH.pub") {
            Write-Host (Get-Content "$SSH_KEY_PATH.pub") -ForegroundColor Yellow
        }
        
    } catch {
        Write-Error "Setup failed: $($_.Exception.Message)"
        exit 1
    }
}

# Run main function
Main
