.PHONY: help init validate plan apply destroy test backup restore puppet-deploy

ENVIRONMENT ?= dev
BACKUP_NAME ?= manual-$(shell date +%Y%m%d-%H%M%S)
PUPPET_ENV ?= production

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

init: ## Initialize the project
	cd terraform/environments/$(ENVIRONMENT) && terraform init
	cd puppet && bundle install
	cd puppet && bolt module install
	helm repo update

validate: ## Validate configurations
	cd terraform/environments/$(ENVIRONMENT) && terraform validate
	cd puppet && pdk validate
	cd puppet && bolt plan show
	kubectl --dry-run=client apply -k k8s/overlays/$(ENVIRONMENT)

puppet-deploy: ## Deploy using Puppet Bolt
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