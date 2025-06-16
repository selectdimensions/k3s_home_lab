.PHONY: help init validate plan apply destroy test backup restore puppet-deploy clean setup-dev

ENVIRONMENT ?= prod
BACKUP_NAME ?= manual-$(shell date +%Y%m%d-%H%M%S)
PUPPET_ENV ?= production
SHELL := /bin/bash

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

help: ## Show this help
	@echo "$(BLUE)Pi Cluster Automation - Available Commands$(NC)"
	@echo "=========================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-30s$(NC) %s\n", $$1, $$2}'

## Setup and Initialization
init: ## Initialize the project
	@echo "$(BLUE)Initializing Pi Cluster project...$(NC)"
	cd terraform/environments/$(ENVIRONMENT) && terraform init
	cd puppet && bundle install || echo "Skipping bundle install"
	@if command -v bolt > /dev/null; then cd puppet && bolt module install; fi
	@if command -v helm > /dev/null; then helm repo add bitnami https://charts.bitnami.com/bitnami && helm repo add prometheus-community https://prometheus-community.github.io/helm-charts && helm repo update; fi
	@echo "$(GREEN)✅ Initialization complete$(NC)"

setup-dev: ## Set up development environment
	@echo "$(BLUE)Setting up development environment...$(NC)"
	@if [ ! -f terraform/environments/$(ENVIRONMENT)/terraform.tfvars ]; then \
		cp terraform/environments/$(ENVIRONMENT)/terraform.tfvars.example terraform/environments/$(ENVIRONMENT)/terraform.tfvars; \
		echo "$(YELLOW)⚠️  Please edit terraform/environments/$(ENVIRONMENT)/terraform.tfvars with your values$(NC)"; \
	fi
	@if [ ! -f inventory.yaml ]; then \
		cp inventory-simple.yaml inventory.yaml; \
		echo "$(YELLOW)⚠️  Please edit inventory.yaml with your Pi IP addresses$(NC)"; \
	fi
	@echo "$(GREEN)✅ Development environment ready$(NC)"

## Validation and Testing
validate: ## Validate all configurations
	@echo "$(BLUE)Validating configurations...$(NC)"
	@echo "$(YELLOW)Validating Terraform...$(NC)"
	cd terraform/environments/$(ENVIRONMENT) && terraform fmt -check=false -write=true
	cd terraform/environments/$(ENVIRONMENT) && terraform validate
	@echo "$(YELLOW)Validating Puppet...$(NC)"
	@if command -v pdk > /dev/null; then cd puppet && pdk validate; else echo "PDK not installed, skipping Puppet validation"; fi
	@echo "$(YELLOW)Validating Kubernetes manifests...$(NC)"
	@if command -v kubectl > /dev/null; then kubectl apply --dry-run=client -k k8s/base/ > /dev/null; else echo "kubectl not available, skipping K8s validation"; fi
	@echo "$(GREEN)✅ All validations passed$(NC)"

test: ## Run all tests
	@echo "$(BLUE)Running tests...$(NC)"
	@if [ -d tests/terraform ]; then cd tests/terraform && go test -v ./...; fi
	@if command -v pdk > /dev/null; then cd puppet && pdk test unit; fi
	@if [ -d tests/integration ]; then cd tests/integration && python -m pytest -v; fi
	@echo "$(GREEN)✅ All tests completed$(NC)"

## Terraform Operations
plan: ## Plan Terraform changes
	@echo "$(BLUE)Planning Terraform changes for $(ENVIRONMENT)...$(NC)"
	cd terraform/environments/$(ENVIRONMENT) && terraform plan -var-file=terraform.tfvars

apply: ## Apply Terraform changes
	@echo "$(BLUE)Applying Terraform changes for $(ENVIRONMENT)...$(NC)"
	@read -p "Are you sure you want to apply changes to $(ENVIRONMENT)? (y/N) " confirm && [ "$$confirm" = "y" ]
	cd terraform/environments/$(ENVIRONMENT) && terraform apply -var-file=terraform.tfvars

destroy: ## Destroy infrastructure (requires confirmation)
	@echo "$(RED)⚠️  WARNING: This will destroy the $(ENVIRONMENT) environment!$(NC)"
	@read -p "Type 'destroy-$(ENVIRONMENT)' to confirm: " confirm && \
	if [ "$$confirm" = "destroy-$(ENVIRONMENT)" ]; then \
		cd terraform/environments/$(ENVIRONMENT) && terraform destroy -var-file=terraform.tfvars -auto-approve; \
		echo "$(RED)🗑️  Environment $(ENVIRONMENT) destroyed$(NC)"; \
	else \
		echo "$(GREEN)Destruction cancelled$(NC)"; \
	fi

## Puppet Operations
puppet-deploy: ## Deploy using Puppet Bolt
	@echo "$(BLUE)Deploying with Puppet Bolt...$(NC)"
	cd puppet && bolt plan run pi_cluster::deploy \
		environment=$(PUPPET_ENV) \
		--targets all \
		--inventoryfile ../inventory.yaml

puppet-status: ## Check Puppet agent status
	@echo "$(BLUE)Checking Puppet agent status...$(NC)"
	cd puppet && bolt command run 'puppet agent -t --noop' \
		--targets all \
		--inventoryfile ../inventory.yaml

## Cluster Operations
cluster-status: ## Check cluster status
	@echo "$(BLUE)Checking cluster status...$(NC)"
	@if command -v kubectl > /dev/null; then \
		echo "$(YELLOW)Nodes:$(NC)"; \
		kubectl get nodes -o wide; \
		echo "$(YELLOW)Pods:$(NC)"; \
		kubectl get pods -A | head -20; \
		echo "$(YELLOW)Services:$(NC)"; \
		kubectl get svc -A | head -10; \
	else \
		echo "$(RED)kubectl not available$(NC)"; \
	fi

cluster-info: ## Display cluster information
	@echo "$(BLUE)Cluster Information$(NC)"
	@echo "==================="
	@echo "Environment: $(GREEN)$(ENVIRONMENT)$(NC)"
	@if [ -f terraform/environments/$(ENVIRONMENT)/terraform.tfstate ]; then \
		echo "Terraform State: $(GREEN)Present$(NC)"; \
	else \
		echo "Terraform State: $(RED)Missing$(NC)"; \
	fi
	@if command -v kubectl > /dev/null && kubectl cluster-info > /dev/null 2>&1; then \
		echo "Kubernetes: $(GREEN)Connected$(NC)"; \
		kubectl cluster-info | head -3; \
	else \
		echo "Kubernetes: $(RED)Not connected$(NC)"; \
	fi

## Backup and Restore
backup: ## Create a manual backup
	@echo "$(BLUE)Creating backup: $(BACKUP_NAME)$(NC)"
	@if command -v velero > /dev/null; then \
		velero backup create $(BACKUP_NAME) --wait; \
	else \
		echo "$(YELLOW)Velero not available, using Puppet backup...$(NC)"; \
		cd puppet && bolt task run pi_cluster::backup_configs \
			backup_name=$(BACKUP_NAME) \
			--targets masters \
			--inventoryfile ../inventory.yaml; \
	fi
	@echo "$(GREEN)✅ Backup created: $(BACKUP_NAME)$(NC)"

restore: ## Restore from backup
	@echo "$(BLUE)Restoring from backup: $(BACKUP_NAME)$(NC)"
	@if [ -z "$(BACKUP_NAME)" ]; then echo "$(RED)Error: BACKUP_NAME required$(NC)"; exit 1; fi
	@read -p "Are you sure you want to restore from $(BACKUP_NAME)? (y/N) " confirm && [ "$$confirm" = "y" ]
	cd puppet && bolt plan run pi_cluster::restore \
		backup_name=$(BACKUP_NAME) \
		environment=$(ENVIRONMENT) \
		--inventoryfile ../inventory.yaml
	@echo "$(GREEN)✅ Restore completed$(NC)"

list-backups: ## List available backups
	@echo "$(BLUE)Available backups:$(NC)"
	@if command -v velero > /dev/null; then \
		velero backup get; \
	else \
		echo "$(YELLOW)Listing local backups...$(NC)"; \
		ls -la backups/ 2>/dev/null || echo "No backups directory found"; \
	fi

## Monitoring
monitor: ## Open monitoring dashboards
	@echo "$(BLUE)Opening monitoring dashboards...$(NC)"
	@echo "Grafana: http://192.168.0.120:30082"
	@echo "Prometheus: http://192.168.0.120:30090"
	@if command -v kubectl > /dev/null; then \
		kubectl port-forward -n monitoring svc/grafana 3000:3000 & \
		kubectl port-forward -n monitoring svc/prometheus 9090:9090 & \
		echo "$(GREEN)Port forwards started in background$(NC)"; \
	fi

logs: ## View cluster logs
	@echo "$(BLUE)Recent cluster logs:$(NC)"
	@if command -v kubectl > /dev/null; then \
		echo "$(YELLOW)Recent events:$(NC)"; \
		kubectl get events --sort-by=.metadata.creationTimestamp | tail -10; \
		echo "$(YELLOW)Recent pod logs:$(NC)"; \
		kubectl logs -n kube-system --tail=10 -l app=traefik; \
	else \
		echo "$(RED)kubectl not available$(NC)"; \
	fi

## Development and Maintenance
clean: ## Clean up temporary files
	@echo "$(BLUE)Cleaning up temporary files...$(NC)"
	find . -name "*.tmp" -delete
	find . -name "*.log" -delete 2>/dev/null || true
	find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "terraform.tfstate.backup" -delete 2>/dev/null || true
	@if [ -f "NUL" ]; then rm -f NUL; fi
	@echo "$(GREEN)✅ Cleanup complete$(NC)"

update-deps: ## Update dependencies
	@echo "$(BLUE)Updating dependencies...$(NC)"
	@if command -v terraform > /dev/null; then \
		cd terraform/environments/$(ENVIRONMENT) && terraform init -upgrade; \
	fi
	@if command -v helm > /dev/null; then \
		helm repo update; \
	fi
	@if [ -f puppet/Gemfile ]; then \
		cd puppet && bundle update; \
	fi
	@echo "$(GREEN)✅ Dependencies updated$(NC)"

format: ## Format code
	@echo "$(BLUE)Formatting code...$(NC)"
	@if command -v terraform > /dev/null; then \
		terraform fmt -recursive terraform/; \
	fi
	@if command -v puppet > /dev/null; then \
		find puppet -name "*.pp" -exec puppet-lint --fix {} \; 2>/dev/null || true; \
	fi
	@echo "$(GREEN)✅ Code formatted$(NC)"

## Quick Actions
quick-deploy: init validate apply ## Quick deployment (init + validate + apply)
	@echo "$(GREEN)✅ Quick deployment completed$(NC)"

quick-status: cluster-status monitor ## Quick status check
	@echo "$(GREEN)✅ Status check completed$(NC)"

## Documentation
docs: ## Generate documentation
	@echo "$(BLUE)Generating documentation...$(NC)"
	@if command -v terraform-docs > /dev/null; then \
		for dir in terraform/modules/*/; do \
			terraform-docs markdown table --output-file README.md "$$dir"; \
		done; \
	fi
	@if [ -f puppet/Gemfile ] && command -v bundle > /dev/null; then \
		cd puppet && bundle exec puppet strings generate --format markdown; \
	fi
	@echo "$(GREEN)✅ Documentation generated$(NC)"

## Emergency Procedures
emergency-stop: ## Emergency stop all services
	@echo "$(RED)🚨 EMERGENCY STOP - Stopping all services$(NC)"
	@if command -v kubectl > /dev/null; then \
		kubectl scale deployment --all --replicas=0 -A; \
		kubectl get pods -A | grep -v "Running\|Completed" || true; \
	fi

emergency-restore: ## Emergency restore from latest backup
	@echo "$(RED)🚨 EMERGENCY RESTORE$(NC)"
	@LATEST_BACKUP=$$(velero backup get --output=name | head -1 | cut -d'/' -f2) && \
	if [ ! -z "$$LATEST_BACKUP" ]; then \
		echo "Restoring from: $$LATEST_BACKUP"; \
		velero restore create emergency-restore-$$(date +%Y%m%d-%H%M) --from-backup=$$LATEST_BACKUP; \
	else \
		echo "$(RED)No backups found$(NC)"; \
	fi

## Environment Management
env-switch: ## Switch environment (usage: make env-switch ENVIRONMENT=staging)
	@echo "$(BLUE)Switching to environment: $(ENVIRONMENT)$(NC)"
	@if [ ! -d "terraform/environments/$(ENVIRONMENT)" ]; then \
		echo "$(RED)Environment $(ENVIRONMENT) does not exist$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✅ Environment set to: $(ENVIRONMENT)$(NC)"
	@echo "Current terraform workspace: $$(cd terraform/environments/$(ENVIRONMENT) && terraform workspace show 2>/dev/null || echo 'default')"

list-envs: ## List available environments
	@echo "$(BLUE)Available environments:$(NC)"
	@ls -1 terraform/environments/
	cd puppet && bolt plan run pi_cluster_automation::deploy \
		--inventoryfile ../inventory.yaml \
		environment=$(ENVIRONMENT) \
		--run-as root

puppet-test: ## Run Puppet tests
	cd puppet && pdk test unit
	cd puppet && pdk test unit --parallel

puppet-facts: ## Gather facts from all nodes
	bolt task run facts --targets all --inventoryfile inventory.yaml

puppet-apply: ## Apply Puppet configuration to specific nodes
	bolt apply puppet/manifests/site.pp \
		--targets $(TARGETS) \
		--inventoryfile inventory.yaml \
		--hiera-config puppet/hiera.yaml

plan: ## Plan infrastructure changes
	cd terraform/environments/$(ENVIRONMENT) && terraform plan -var-file=terraform.tfvars

apply: ## Apply infrastructure changes and run Puppet
	cd terraform/environments/$(ENVIRONMENT) && terraform apply -var-file=terraform.tfvars -auto-approve
	$(MAKE) puppet-deploy

destroy: ## Destroy infrastructure
	@echo "WARNING: This will destroy all infrastructure in $(ENVIRONMENT)"
	@read -p "Type 'destroy-$(ENVIRONMENT)' to confirm: " confirm && \
	if [ "$$confirm" = "destroy-$(ENVIRONMENT)" ]; then \
		cd terraform/environments/$(ENVIRONMENT) && terraform destroy -var-file=terraform.tfvars -auto-approve; \
	else \
		echo "Destruction cancelled"; \
	fi

test: ## Run all tests
	cd tests/terraform && go test -v ./...
	cd puppet && pdk test unit
	cd tests/integration && pytest -v

backup: ## Create a manual backup
	velero backup create $(BACKUP_NAME) --wait
	bolt task run pi_cluster_automation::backup_configs \
		--targets masters \
		--inventoryfile inventory.yaml

restore: ## Restore from backup
	bolt plan run pi_cluster_automation::restore \
		backup_name=$(BACKUP_NAME) \
		environment=$(ENVIRONMENT) \
		--inventoryfile inventory.yaml

monitor: ## Open monitoring dashboards
	@echo "Opening Grafana..."
	kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

puppet-console: ## Open Puppet console (if using PE)
	@echo "Opening Puppet Console..."
	@echo "https://puppet.$(CLUSTER_DOMAIN)"

node-shell: ## Get shell on a node
	bolt command run 'sudo -i' --targets $(TARGET) --inventoryfile inventory.yaml

cluster-status: ## Check cluster status
	bolt task run pi_cluster_automation::cluster_status \
		--targets masters \
		--inventoryfile inventory.yaml