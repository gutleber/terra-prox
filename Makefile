.PHONY: help init validate plan-dev apply-dev plan-staging apply-staging plan-prod apply-prod \
	plan-zfs apply-zfs destroy-zfs \
	destroy-dev destroy-staging destroy-prod clean fmt lint test docs

# Default target
help:
	@echo "Proxmox Terraform Project"
	@echo "=========================="
	@echo ""
	@echo "Available targets:"
	@echo "  init              - Initialize Terraform"
	@echo "  validate          - Validate Terraform configuration"
	@echo "  fmt               - Format Terraform code"
	@echo ""
	@echo "Development:"
	@echo "  plan-dev          - Plan DEV environment"
	@echo "  apply-dev         - Apply DEV environment"
	@echo "  destroy-dev       - Destroy DEV environment"
	@echo ""
	@echo "Staging:"
	@echo "  plan-staging      - Plan STAGING environment"
	@echo "  apply-staging     - Apply STAGING environment"
	@echo "  destroy-staging   - Destroy STAGING environment"
	@echo ""
	@echo "Production:"
	@echo "  plan-prod         - Plan PROD environment"
	@echo "  apply-prod        - Apply PROD environment"
	@echo "  destroy-prod      - Destroy PROD environment"
	@echo ""
	@echo "ZFS RAID1 (Proxmox 9.1.1+):"
	@echo "  plan-zfs          - Plan DEV environment with ZFS storage"
	@echo "  apply-zfs         - Apply DEV environment with ZFS storage"
	@echo "  destroy-zfs       - Destroy DEV environment with ZFS storage"
	@echo ""
	@echo "Utilities:"
	@echo "  clean             - Remove Terraform cache and plans"
	@echo "  lint              - Run validation and formatting checks"
	@echo "  docs              - Generate documentation"
	@echo ""

# Initialize
init:
	@echo "Initializing Terraform..."
	@cd terraform && terraform init -upgrade
	@echo "✓ Terraform initialized"

# Validation
validate:
	@echo "Validating Terraform configuration..."
	@cd terraform && terraform validate
	@echo "✓ Configuration valid"

# Formatting
fmt:
	@echo "Formatting Terraform code..."
	@cd terraform && terraform fmt -recursive .
	@echo "✓ Code formatted"

# Linting
lint: validate fmt
	@echo "✓ Lint checks passed"

# Development Environment
plan-dev:
	@echo "Planning DEV environment..."
	@cd terraform && terraform plan -var-file=environments/dev/terraform.tfvars

apply-dev:
	@echo "Applying DEV environment..."
	@cd terraform && terraform apply -var-file=environments/dev/terraform.tfvars

destroy-dev:
	@echo "Destroying DEV environment..."
	@cd terraform && terraform destroy -var-file=environments/dev/terraform.tfvars

# Staging Environment
plan-staging:
	@echo "Planning STAGING environment..."
	@cd terraform && terraform plan -var-file=environments/staging/terraform.tfvars

apply-staging:
	@echo "Applying STAGING environment..."
	@cd terraform && terraform apply -var-file=environments/staging/terraform.tfvars

destroy-staging:
	@echo "Destroying STAGING environment..."
	@cd terraform && terraform destroy -var-file=environments/staging/terraform.tfvars

# Production Environment
plan-prod:
	@echo "Planning PROD environment..."
	@cd terraform && terraform plan -var-file=environments/prod/terraform.tfvars

apply-prod:
	@echo "Applying PROD environment..."
	@cd terraform && terraform apply -var-file=environments/prod/terraform.tfvars

destroy-prod:
	@echo "WARNING: Destroying PRODUCTION environment!"
	@cd terraform && terraform destroy -var-file=environments/prod/terraform.tfvars

# ZFS RAID1 Environment (for Proxmox VE 9.1.1 with ZFS storage)
plan-zfs:
	@echo "Planning ZFS environment..."
	@cd terraform && terraform plan -var-file=environments/dev-zfs/terraform.tfvars

apply-zfs:
	@echo "Applying ZFS environment..."
	@cd terraform && terraform apply -var-file=environments/dev-zfs/terraform.tfvars

destroy-zfs:
	@echo "Destroying ZFS environment..."
	@cd terraform && terraform destroy -var-file=environments/dev-zfs/terraform.tfvars

# Utilities
clean:
	@echo "Cleaning Terraform cache..."
	@cd terraform && rm -rf .terraform/ *.plan terraform.tfstate* .terraform.lock.hcl
	@echo "✓ Cache cleaned"

docs:
	@echo "Documentation is available in docs/"
	@echo "  - README.md - Project overview"
	@echo "  - docs/ARCHITECTURE.md - Architecture documentation"
	@echo "  - docs/DEPLOYMENT.md - Deployment guide"

# Helper targets
check-env:
	@if [ ! -f .env ]; then \
		echo "Error: .env file not found"; \
		exit 1; \
	fi
	@echo "✓ .env file exists"

run-scripts:
	@chmod +x scripts/*.sh
	@echo "✓ Scripts are executable"

.DEFAULT_GOAL := help
