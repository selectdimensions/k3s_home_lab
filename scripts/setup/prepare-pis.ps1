# PowerShell script to prepare Raspberry Pi nodes for the k3s cluster
# This script automates the initial setup of Pi nodes from Windows

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string[]]$PiAddresses = @("192.168.0.120", "192.168.0.121", "192.168.0.122", "192.168.0.123"),

    [Parameter(Mandatory=$true)]
    [string]$Username = "hezekiah",

    [string]$InitialUser = "hezekiah",
    [string]$InitialPassword = "hezekiah",
    [string]$SSHKeyPath = "$env:USERPROFILE\.ssh\keys\hobby\pi_k3s_cluster.pub"
)

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

# Function to execute SSH commands
function Invoke-SSHCommand {
    param(
        [string]$Server,
        [string]$Username,
        [string]$Password,
        [string]$Command,
        [string]$SSHKeyPath = $null
    )

    try {
        if ($SSHKeyPath -and (Test-Path $SSHKeyPath)) {
            # Use key-based authentication
            $result = ssh -o "StrictHostKeyChecking=no" -i $SSHKeyPath "$Username@$Server" $Command
        } else {
            # Use password authentication (requires sshpass or interactive)
            Write-Warning "Key-based auth not available, you may need to enter password for $Server"
            $result = ssh -o "StrictHostKeyChecking=no" "$Username@$Server" $Command
        }
        return $result
    } catch {
        Write-Error "SSH command failed for $Server : $($_.Exception.Message)"
        return $null
    }
}

# Function to copy SSH key to Pi
function Copy-SSHKey {
    param(
        [string]$Server,
        [string]$Username,
        [string]$SSHKeyPath
    )

    if (!(Test-Path $SSHKeyPath)) {
        Write-Error "SSH public key not found at $SSHKeyPath"
        return $false
    }

    Write-Info "Copying SSH key to $Server..."

    try {
        # Copy the public key
        $pubKeyContent = Get-Content $SSHKeyPath

        # Create the command to add the key
        $addKeyCommand = @"
mkdir -p ~/.ssh && \
echo '$pubKeyContent' >> ~/.ssh/authorized_keys && \
chmod 700 ~/.ssh && \
chmod 600 ~/.ssh/authorized_keys && \
sort ~/.ssh/authorized_keys | uniq > ~/.ssh/authorized_keys.tmp && \
mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys
"@

        # Execute the command
        Write-Warning "Please enter password for $Username@$Server when prompted"
        ssh -o "StrictHostKeyChecking=no" "$Username@$Server" $addKeyCommand

        if ($LASTEXITCODE -eq 0) {
            Write-Step "SSH key successfully added to $Server"
            return $true
        } else {
            Write-Error "Failed to add SSH key to $Server"
            return $false
        }
    } catch {
        Write-Error "Error copying SSH key to $Server : $($_.Exception.Message)"
        return $false
    }
}

# Function to prepare a single Pi
function Initialize-PiNode {
    param(
        [string]$PiAddress,
        [string]$NodeName,
        [string]$Username
    )

    Write-Step "Preparing Pi node: $NodeName ($PiAddress)"

    # First, copy SSH key if not already done
    if (!(Copy-SSHKey -Server $PiAddress -Username $Username -SSHKeyPath $SSHKeyPath)) {
        Write-Error "Failed to set up SSH key for $PiAddress"
        return $false
    }

    # Test SSH connection with key
    Write-Info "Testing SSH connection to $PiAddress..."
    $testResult = Invoke-SSHCommand -Server $PiAddress -Username $Username -Command "hostname" -SSHKeyPath ($SSHKeyPath -replace '\.pub$', '')

    if (!$testResult) {
        Write-Error "SSH connection test failed for $PiAddress"
        return $false
    }

    Write-Info "Connected successfully to $testResult"

    # Prepare the Pi with necessary configurations
    $setupCommands = @(
        # Update system
        "sudo apt-get update",

        # Install essential packages
        "sudo apt-get install -y curl wget git vim htop python3-pip",

        # Enable cgroups for K3s
        "echo ' cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1' | sudo tee -a /boot/cmdline.txt",

        # Set hostname
        "echo '$NodeName' | sudo tee /etc/hostname",
        "sudo sed -i 's/127.0.1.1.*/127.0.1.1 $NodeName/' /etc/hosts",

        # Configure SSH
        "sudo systemctl enable ssh",
        "sudo systemctl start ssh",

        # Set timezone
        "sudo timedatectl set-timezone America/New_York",

        # Create user if not exists
        "id $Username || sudo adduser --disabled-password --gecos '' $Username",
        "sudo usermod -aG sudo $Username",

        # Disable password authentication for security
        "sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config",
        "sudo systemctl reload ssh"
    )

    foreach ($command in $setupCommands) {
        Write-Info "Executing: $command"
        $result = Invoke-SSHCommand -Server $PiAddress -Username $Username -Command $command -SSHKeyPath ($SSHKeyPath -replace '\.pub$', '')

        if ($LASTEXITCODE -ne 0 -and $command -notlike "*adduser*") {
            Write-Warning "Command failed but continuing: $command"
        }
    }

    Write-Step "Pi node $NodeName prepared successfully!"
    Write-Warning "Please reboot $NodeName to apply cgroup changes: sudo reboot"

    return $true
}

# Function to verify inventory file
function Test-InventoryFile {
    $inventoryPath = "inventory.yaml"
    if (!(Test-Path $inventoryPath)) {
        Write-Error "inventory.yaml not found in current directory"
        return $false
    }

    Write-Info "Found inventory.yaml file"
    return $true
}

# Main execution
function Main {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Blue
    Write-Host "   Pi Cluster Node Preparation Script          " -ForegroundColor Blue
    Write-Host "================================================" -ForegroundColor Blue
    Write-Host ""

    Write-Info "This script will prepare your Raspberry Pi nodes for the k3s cluster"
    Write-Info "Pi addresses to configure: $($PiAddresses -join ', ')"
    Write-Info "SSH public key: $SSHKeyPath"
    Write-Host ""

    if (!(Test-Path $SSHKeyPath)) {
        Write-Error "SSH public key not found at $SSHKeyPath"
        Write-Info "Please run setup-windows.ps1 first to generate SSH keys"
        exit 1
    }

    $confirmation = Read-Host "Continue with Pi preparation? (y/n)"
    if ($confirmation -notin @('y', 'Y', 'yes', 'Yes')) {
        Write-Info "Pi preparation cancelled by user"
        exit 0
    }

    # Node names corresponding to IP addresses
    $nodeNames = @("pi-master", "pi-worker-1", "pi-worker-2", "pi-worker-3")

    $successCount = 0

    for ($i = 0; $i -lt $PiAddresses.Length; $i++) {
        $piAddress = $PiAddresses[$i]
        $nodeName = if ($i -lt $nodeNames.Length) { $nodeNames[$i] } else { "pi-node-$($i+1)" }

        Write-Host ""
        Write-Host "----------------------------------------" -ForegroundColor Cyan

        if (Initialize-PiNode -PiAddress $piAddress -NodeName $nodeName -Username $Username) {
            $successCount++
        }
    }

    Write-Host ""
    Write-Host "================================================" -ForegroundColor Blue
    Write-Step "Pi preparation completed!"
    Write-Info "Successfully configured: $successCount / $($PiAddresses.Length) nodes"
    Write-Host ""

    if ($successCount -eq $PiAddresses.Length) {
        Write-Step "All nodes prepared successfully! 🎉"
        Write-Host ""
        Write-Info "Next steps:"
        Write-Host "  1. Reboot all Pi nodes to apply cgroup changes"
        Write-Host "  2. Wait for nodes to come back online"
        Write-Host "  3. Run: make init (to initialize Terraform and Puppet modules)"
        Write-Host "  4. Run: make puppet-deploy (to deploy the cluster)"
        Write-Host ""
        Write-Info "Reboot commands:"
        for ($i = 0; $i -lt $PiAddresses.Length; $i++) {
            $address = $PiAddresses[$i]
            Write-Host "  ssh -i $($SSHKeyPath -replace '\.pub$', '') $Username@$address 'sudo reboot'" -ForegroundColor Yellow
        }
    } else {
        Write-Warning "Some nodes failed to configure. Please check the errors above."
        Write-Info "You can re-run this script to retry failed nodes."
    }
}

# Run main function
Main
