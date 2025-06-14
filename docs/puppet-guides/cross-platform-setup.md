# Cross-Platform Setup Guide

## Overview
This guide covers setting up Puppet agents on different operating systems to manage your Pi cluster infrastructure.

## Supported Platforms
- Raspberry Pi OS (ARM)
- Ubuntu/Debian (x86_64)
- Windows Server 2019/2022
- macOS (for development)

## Installation

### Raspberry Pi / Linux
```bash
./scripts/setup/install-puppet-agent.sh puppet.cluster.local prod
```
### Windows
```powershell
.\scripts\setup\install-puppet-agent.ps1 -PuppetServer puppet.cluster.local -Environment prod
```

### macOS
```bash
brew install --cask puppet-agent
./scripts/setup/install-puppet-agent.sh puppet.cluster.local dev
```

### Verification
```bash
# Check Puppet agent status
sudo puppet agent --test

# View last run report
sudo puppet last_run_report print
```

### Bolt Usage
##### Running commands across platforms
```bash
# Run on all nodes
bolt command run 'echo "Hello from $(hostname)"' --targets all

# Run on specific OS
bolt command run 'uname -a' --targets linux_nodes
bolt command run 'Get-ComputerInfo' --targets windows_nodes
```

### Applying configurations
```bash
# Apply a specific profile
bolt apply --execute 'include profiles::monitoring_agent' --targets workers
```

### Troubleshooting
##### Certificate Issues
```bash
# Clean certificates
sudo puppet ssl clean $(hostname -f)

# Regenerate certificates
sudo puppet agent -t --waitforcert 60
```

### Connectivity Issues
```bash
# Test Puppet server connection
telnet puppet.cluster.local 8140

# Check Puppet configuration
puppet config print --section agent
```

## Benefits of Using Puppet

1. **True Cross-Platform Support**: Native support for Windows, macOS, and Linux
2. **Declarative Configuration**: Define desired state, Puppet handles implementation
3. **Puppet Forge**: Extensive module ecosystem for common tasks
4. **Bolt Orchestration**: Agentless task execution and plan orchestration
5. **Enterprise Features**: Optional Puppet Enterprise for GUI, RBAC, and compliance
6. **Hiera Data Management**: Separate configuration data from code
7. **Strong Testing Framework**: RSpec-puppet for comprehensive testing
8. **Mature Ecosystem**: Well-established tool with extensive documentation
9. **Reporting & Compliance**: Built-in reporting and compliance features
10. **Scale**: Efficiently manages thousands of nodes

This structure provides a production-ready, cross-platform Pi cluster infrastructure management solution using Puppet.