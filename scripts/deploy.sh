#!/bin/bash

# Deploy script for Proxmox Terraform configuration
# Usage: ./scripts/deploy.sh [dev|staging|prod] [plan|apply|destroy]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_DIR/terraform"

# Functions
print_usage() {
    echo "Usage: $0 [dev|staging|prod] [plan|apply|destroy]"
    echo ""
    echo "Examples:"
    echo "  $0 dev plan"
    echo "  $0 dev apply"
    echo "  $0 staging plan"
    echo "  $0 prod apply"
    exit 1
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

check_prerequisites() {
    print_info "Checking prerequisites..."

    # Check Terraform installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed"
        exit 1
    fi
    print_success "Terraform found: $(terraform version -json | grep terraform_version)"

    # Check .env file
    if [ ! -f "$PROJECT_DIR/.env" ]; then
        print_error ".env file not found. Create it with Proxmox credentials."
        exit 1
    fi
    print_success ".env file found"

    # Check Terraform directory
    if [ ! -d "$TERRAFORM_DIR" ]; then
        print_error "Terraform directory not found at $TERRAFORM_DIR"
        exit 1
    fi
    print_success "Terraform directory found"

    # Check environment tfvars file
    if [ ! -f "$TERRAFORM_DIR/environments/$ENVIRONMENT/terraform.tfvars" ]; then
        print_error "Environment tfvars not found: environments/$ENVIRONMENT/terraform.tfvars"
        exit 1
    fi
    print_success "Environment configuration found"
}

terraform_init() {
    print_info "Initializing Terraform..."
    cd "$TERRAFORM_DIR"
    terraform init -upgrade
    print_success "Terraform initialized"
}

terraform_plan() {
    print_info "Planning Terraform changes for $ENVIRONMENT environment..."
    cd "$TERRAFORM_DIR"

    # Source environment variables
    set -a
    source "$PROJECT_DIR/.env"
    set +a

    terraform plan \
        -var-file="environments/$ENVIRONMENT/terraform.tfvars" \
        -out="$ENVIRONMENT.plan"

    print_success "Plan saved to $ENVIRONMENT.plan"
    echo ""
    echo "Review the plan above. To apply, run:"
    echo "  $0 $ENVIRONMENT apply"
}

terraform_apply() {
    print_info "Applying Terraform configuration for $ENVIRONMENT environment..."

    # Check if plan file exists
    if [ ! -f "$TERRAFORM_DIR/$ENVIRONMENT.plan" ]; then
        print_error "Plan file not found. Run 'plan' first: $0 $ENVIRONMENT plan"
        exit 1
    fi

    cd "$TERRAFORM_DIR"

    # Source environment variables
    set -a
    source "$PROJECT_DIR/.env"
    set +a

    # Confirmation for prod
    if [ "$ENVIRONMENT" = "prod" ]; then
        echo ""
        echo -e "${RED}WARNING: You are about to modify PRODUCTION infrastructure!${NC}"
        echo "This operation may affect running services."
        echo ""
        read -p "Type 'yes' to confirm: " -r
        if [ "$REPLY" != "yes" ]; then
            print_error "Deployment cancelled"
            exit 1
        fi
    fi

    terraform apply "$ENVIRONMENT.plan"

    # Clean up plan file
    rm -f "$ENVIRONMENT.plan"

    print_success "Terraform apply completed for $ENVIRONMENT environment"
}

terraform_destroy() {
    print_info "Destroying Terraform resources for $ENVIRONMENT environment..."

    cd "$TERRAFORM_DIR"

    # Source environment variables
    set -a
    source "$PROJECT_DIR/.env"
    set +a

    # Double confirmation for any destroy
    echo ""
    echo -e "${RED}WARNING: You are about to destroy all infrastructure!${NC}"
    read -p "Type 'yes' to confirm: " -r
    if [ "$REPLY" != "yes" ]; then
        print_error "Destroy cancelled"
        exit 1
    fi

    if [ "$ENVIRONMENT" = "prod" ]; then
        echo -e "${RED}DOUBLE CONFIRMATION: Destroying PRODUCTION!${NC}"
        read -p "Type 'yes' again to confirm: " -r
        if [ "$REPLY" != "yes" ]; then
            print_error "Destroy cancelled"
            exit 1
        fi
    fi

    terraform destroy -var-file="environments/$ENVIRONMENT/terraform.tfvars" -auto-approve

    print_success "Terraform resources destroyed for $ENVIRONMENT environment"
}

terraform_output() {
    print_info "Terraform outputs for $ENVIRONMENT environment:"
    cd "$TERRAFORM_DIR"
    terraform output -var-file="environments/$ENVIRONMENT/terraform.tfvars"
}

# Main script
main() {
    # Check arguments
    if [ $# -lt 2 ]; then
        print_usage
    fi

    ENVIRONMENT=$1
    ACTION=$2

    # Validate environment
    case $ENVIRONMENT in
        dev|staging|prod)
            ;;
        *)
            print_error "Invalid environment: $ENVIRONMENT"
            print_usage
            ;;
    esac

    # Validate action
    case $ACTION in
        plan|apply|destroy|init|output)
            ;;
        *)
            print_error "Invalid action: $ACTION"
            print_usage
            ;;
    esac

    print_info "Starting $ACTION for $ENVIRONMENT environment..."
    echo ""

    # Execute action
    check_prerequisites

    case $ACTION in
        init)
            terraform_init
            ;;
        plan)
            terraform_plan
            ;;
        apply)
            terraform_apply
            ;;
        destroy)
            terraform_destroy
            ;;
        output)
            terraform_output
            ;;
    esac
}

# Run main function
main "$@"
