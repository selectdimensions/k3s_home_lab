#!/bin/bash
# Complete bootstrap script

set -e

echo "🚀 Pi Cluster Bootstrap with Terraform & Ansible"
echo "=============================================="

# Check dependencies
check_deps() {
    local deps=("terraform" "ansible" "kubectl" "helm")
    for dep in "${deps[@]}"; do
        if ! command -v $dep &>/dev/null; then
            echo "❌ Missing: $dep"
            echo "Please install $dep first"
            exit 1
        fi
    done
    echo "✅ All dependencies installed"
}

# Initialize Terraform
init_terraform() {
    echo "📦 Initializing Terraform..."
    cd terraform
    terraform init
}

# Run Terraform
deploy_infrastructure() {
    echo "🏗️  Deploying infrastructure..."
    cd terraform
    
    # Create terraform.tfvars if it doesn't exist
    if [ ! -f terraform.tfvars ]; then
        cat > terraform.tfvars << EOF
postgres_password = "SecurePostgresPassword123"
minio_secret_key  = "SecureMinioPassword123"
EOF
        echo "📝 Created terraform.tfvars - please update with secure passwords"
    fi
    
    terraform plan
    terraform apply -auto-approve
}

# Main execution
main() {
    check_deps
    
    echo "This will:"
    echo "1. Configure all Pi nodes with static IPs"
    echo "2. Install K3s cluster"
    echo "3. Deploy MetalLB, PostgreSQL, MinIO, etc."
    echo ""
    read -p "Continue? (y/n) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        init_terraform
        deploy_infrastructure
        
        echo ""
        echo "✅ Deployment complete!"
        echo ""
        echo "Check cluster status:"
        echo "  kubectl get nodes"
        echo "  kubectl get svc -A"
    fi
}

main