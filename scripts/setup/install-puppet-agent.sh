#!/bin/bash
# Cross-platform Puppet agent installation script

set -euo pipefail

PUPPET_SERVER=${1:-puppet.cluster.local}
ENVIRONMENT=${2:-prod}
OS_TYPE=$(uname -s)

install_puppet_debian() {
    wget https://apt.puppet.com/puppet7-release-$(lsb_release -cs).deb
    sudo dpkg -i puppet7-release-$(lsb_release -cs).deb
    sudo apt-get update
    sudo apt-get install -y puppet-agent
}

install_puppet_redhat() {
    sudo rpm -Uvh https://yum.puppet.com/puppet7-release-el-$(rpm -E %{rhel}).noarch.rpm
    sudo yum install -y puppet-agent
}

install_puppet_macos() {
    brew install --cask puppet-agent
}

configure_puppet() {
    sudo /opt/puppetlabs/bin/puppet config set server $PUPPET_SERVER --section main
    sudo /opt/puppetlabs/bin/puppet config set environment $ENVIRONMENT --section main
    sudo /opt/puppetlabs/bin/puppet config set runinterval 30m --section main
}

case "$OS_TYPE" in
    Linux)
        if [ -f /etc/debian_version ]; then
            install_puppet_debian
        elif [ -f /etc/redhat-release ]; then
            install_puppet_redhat
        fi
        ;;
    Darwin)
        install_puppet_macos
        ;;
    *)
        echo "Unsupported OS: $OS_TYPE"
        exit 1
        ;;
esac

configure_puppet

# Enable and start Puppet
sudo /opt/puppetlabs/bin/puppet resource service puppet ensure=running enable=true

echo "Puppet agent installed and configured successfully!"