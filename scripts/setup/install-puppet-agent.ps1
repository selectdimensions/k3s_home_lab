# PowerShell script for Windows nodes
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$PuppetServer,
    
    [Parameter(Mandatory=$true)]
    [string]$Environment = "prod",
    
    [string]$PuppetVersion = "7.26.0"
)

# Download and install Puppet agent
$puppetMSI = "puppet-agent-$PuppetVersion-x64.msi"
$downloadUrl = "https://downloads.puppet.com/windows/puppet7/$puppetMSI"

Write-Host "Downloading Puppet Agent..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $puppetMSI

Write-Host "Installing Puppet Agent..."
Start-Process msiexec.exe -ArgumentList "/i $puppetMSI /qn /norestart PUPPET_MASTER_SERVER=$PuppetServer" -Wait

# Configure Puppet
$puppetConf = @"
[main]
server = $PuppetServer
environment = $Environment
runinterval = 30m
"@

Set-Content -Path "C:\ProgramData\PuppetLabs\puppet\etc\puppet.conf" -Value $puppetConf

# Start Puppet service
Start-Service -Name puppet
Set-Service -Name puppet -StartupType Automatic

Write-Host "Puppet Agent installed and configured successfully!"