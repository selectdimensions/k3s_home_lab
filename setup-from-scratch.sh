#!/bin/bash
# Complete setup script for Puppet-based Pi Cluster

set -euo pipefail

# Configuration
PUPPET_SERVER_IP="192.168.0.120"  # Replace with your Puppet Server IP
CLUSTER_DOMAIN="cluster.local"
ENVIRONMENT="production"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Step 1: Install Puppet Bolt on your local machine
install_bolt() {
    log "Installing Puppet Bolt on local machine..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        wget -O - https://apt.puppet.com/puppet-tools-release-focal.deb | sudo dpkg -i -
        sudo apt-get update
        sudo apt-get install -y puppet-bolt
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        brew install --cask puppet-bolt
    else
        error "Unsupported OS type: $OSTYPE"
    fi
    
    log "Puppet Bolt installed successfully"
}

# Step 2: Set up SSH keys
setup_ssh_keys() {
    log "Setting up SSH keys..."
    
    SSH_KEY_PATH="$HOME/.ssh/keys/hobby/pi_k3s_cluster"
    
    if [ ! -f "$SSH_KEY_PATH" ]; then
        mkdir -p "$(dirname "$SSH_KEY_PATH")"
        ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "pi-cluster-automation"
        log "SSH key generated at $SSH_KEY_PATH"
    else
        log "SSH key already exists at $SSH_KEY_PATH"
    fi
    
    # Display public key
    info "Add this public key to your Pi nodes:"
    cat "${SSH_KEY_PATH}.pub"
    echo ""
    read -p "Press Enter once you've added the SSH key to all nodes..."
}

# Step 3: Test connectivity
test_connectivity() {
    log "Testing connectivity to all nodes..."
    
    # Test using bolt
    bolt command run 'hostname' --targets all --inventoryfile inventory.yaml
    
    if [ $? -eq 0 ]; then
        log "Successfully connected to all nodes"
    else
        error "Failed to connect to some nodes. Please check your inventory.yaml and SSH setup"
    fi
}

# Step 4: Install Puppet Server
install_puppet_server() {
    log "Installing Puppet Server on ${PUPPET_SERVER_IP}..."
    
    # Create installation script
    cat > /tmp/install-puppet-server.sh << 'EOF'
#!/bin/bash
# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install Puppet Server
wget https://apt.puppet.com/puppet7-release-bullseye.deb
sudo dpkg -i puppet7-release-bullseye.deb
sudo apt-get update
sudo apt-get install -y puppetserver

# Configure Puppet Server
sudo sed -i 's/-Xms2g/-Xms512m/g' /etc/default/puppetserver
sudo sed -i 's/-Xmx2g/-Xmx512m/g' /etc/default/puppetserver

# Configure autosign for the cluster domain
echo "*.cluster.local" | sudo tee /etc/puppetlabs/puppet/autosign.conf

# Start and enable Puppet Server
sudo systemctl start puppetserver
sudo systemctl enable puppetserver

# Configure firewall
sudo ufw allow 8140/tcp
sudo ufw allow 8142/tcp
sudo ufw allow 8143/tcp

echo "Puppet Server installation complete!"
EOF

    # Copy and run installation script
    bolt file upload /tmp/install-puppet-server.sh /tmp/install-puppet-server.sh \
        --targets puppet-server \
        --inventoryfile inventory.yaml
    
    bolt command run 'chmod +x /tmp/install-puppet-server.sh && /tmp/install-puppet-server.sh' \
        --targets puppet-server \
        --inventoryfile inventory.yaml
        
    log "Waiting for Puppet Server to start..."
    sleep 30
}

# Step 5: Deploy Puppet code
deploy_puppet_code() {
    log "Deploying Puppet code to Puppet Server..."
    
    # Create r10k configuration
    cat > /tmp/r10k.yaml << EOF
cachedir: '/opt/puppetlabs/puppet/cache/r10k'
sources:
  production:
    remote: 'https://github.com/selectdimensions/k3s_home_lab.git'
    basedir: '/etc/puppetlabs/code/environments'
EOF

    # Install r10k and deploy
    bolt command run 'sudo gem install r10k' \
        --targets puppet-server \
        --inventoryfile inventory.yaml
    
    bolt file upload /tmp/r10k.yaml /etc/puppetlabs/puppet/r10k.yaml \
        --targets puppet-server \
        --inventoryfile inventory.yaml
    
    # Deploy Puppet code
    bolt command run 'sudo r10k deploy environment -pv' \
        --targets puppet-server \
        --inventoryfile inventory.yaml
}

# Step 6: Install Puppet agents on all nodes
install_puppet_agents() {
    log "Installing Puppet agents on all nodes..."
    
    bolt plan run pi_cluster_automation::install_agents \
        puppet_server="${PUPPET_SERVER_IP}" \
        environment="${ENVIRONMENT}" \
        --inventoryfile inventory.yaml
}

# Step 7: Run initial Puppet configuration
run_initial_puppet() {
    log "Running initial Puppet configuration..."
    
    # Run puppet agent on all nodes
    bolt command run 'sudo puppet agent -t' \
        --targets all \
        --inventoryfile inventory.yaml
}

# Step 8: Deploy K3s cluster
deploy_k3s() {
    log "Deploying K3s cluster..."
    
    bolt plan run pi_cluster_automation::deploy \
        environment="${ENVIRONMENT}" \
        --inventoryfile inventory.yaml
}

# Main execution
main() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}   Pi Cluster Setup with Puppet - From Scratch  ${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
    
    info "This script will:"
    echo "  1. Install Puppet Bolt locally"
    echo "  2. Set up SSH keys"
    echo "  3. Test connectivity to all nodes"
    echo "  4. Install Puppet Server"
    echo "  5. Deploy Puppet code"
    echo "  6. Install Puppet agents on all nodes"
    echo "  7. Run initial configuration"
    echo "  8. Deploy K3s cluster"
    echo ""
    
    read -p "Continue? (y/n) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    # Check if inventory.yaml exists
    if [ ! -f "inventory.yaml" ]; then
        error "inventory.yaml not found. Please create it first."
    fi
    
    # Execute steps
    install_bolt
    setup_ssh_keys
    test_connectivity
    install_puppet_server
    deploy_puppet_code
    install_puppet_agents
    run_initial_puppet
    deploy_k3s
    
    echo ""
    log "Setup complete! 🎉"
    echo ""
    info "Next steps:"
    echo "  - Access Puppet Server: https://${PUPPET_SERVER_IP}:443"
    echo "  - Check cluster status: kubectl get nodes"
    echo "  - View Puppet reports: sudo puppet report list"
    echo ""
}

# Run main function
main "$@"