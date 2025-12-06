#!/bin/bash

# Validation script for Proxmox Terraform configuration
# Checks configuration, credentials, and connectivity

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

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Functions
print_test() {
    echo -n "[TEST] $1 ... "
}

print_pass() {
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
}

print_fail() {
    echo -e "${RED}FAIL${NC}"
    ((FAILED++))
}

print_warn() {
    echo -e "${YELLOW}WARN${NC}"
    ((WARNINGS++))
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

# Tests
test_terraform_installed() {
    print_test "Terraform installed"
    if command -v terraform &> /dev/null; then
        print_pass
    else
        print_fail
    fi
}

test_terraform_version() {
    print_test "Terraform version >= 1.5.0"
    TERRAFORM_VERSION=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)

    if [ -z "$TERRAFORM_VERSION" ]; then
        print_fail
        return
    fi

    # Simple version comparison
    if [[ "$TERRAFORM_VERSION" > "1.5.0" ]] || [[ "$TERRAFORM_VERSION" == "1.5.0" ]]; then
        print_pass
    else
        print_fail
    fi
}

test_terraform_directory() {
    print_test "Terraform directory exists"
    if [ -d "$TERRAFORM_DIR" ]; then
        print_pass
    else
        print_fail
    fi
}

test_terraform_files() {
    print_test "Required Terraform files exist"
    local missing=false

    for file in providers.tf variables.tf outputs.tf main.tf; do
        if [ ! -f "$TERRAFORM_DIR/$file" ]; then
            echo "  Missing: $file"
            missing=true
        fi
    done

    if [ "$missing" = false ]; then
        print_pass
    else
        print_fail
    fi
}

test_modules_exist() {
    print_test "Terraform modules exist"
    local missing=false

    for module in template vm lxc; do
        if [ ! -d "$TERRAFORM_DIR/modules/$module" ]; then
            echo "  Missing module: $module"
            missing=true
        fi
    done

    if [ "$missing" = false ]; then
        print_pass
    else
        print_fail
    fi
}

test_environments_exist() {
    print_test "Environment configurations exist"
    local missing=false

    for env in dev staging prod; do
        if [ ! -f "$TERRAFORM_DIR/environments/$env/terraform.tfvars" ]; then
            echo "  Missing: $env/terraform.tfvars"
            missing=true
        fi
    done

    if [ "$missing" = false ]; then
        print_pass
    else
        print_fail
    fi
}

test_env_file() {
    print_test ".env file exists"
    if [ -f "$PROJECT_DIR/.env" ]; then
        print_pass
    else
        print_fail
        echo "  Create .env file with Proxmox credentials"
    fi
}

test_env_variables() {
    print_test "Required environment variables set"
    if [ ! -f "$PROJECT_DIR/.env" ]; then
        print_warn
        return
    fi

    set -a
    source "$PROJECT_DIR/.env" 2>/dev/null || true
    set +a

    local missing=false
    for var in TF_VAR_pve_api_url TF_VAR_pve_token_id TF_VAR_pve_token_secret TF_VAR_pve_user TF_VAR_pve_ssh_key_private; do
        if [ -z "${!var}" ]; then
            echo "  Missing: $var"
            missing=true
        fi
    done

    if [ "$missing" = false ]; then
        print_pass
    else
        print_fail
    fi
}

test_ssh_key() {
    print_test "SSH key accessible"
    if [ ! -f "$PROJECT_DIR/.env" ]; then
        print_warn
        return
    fi

    set -a
    source "$PROJECT_DIR/.env" 2>/dev/null || true
    set +a

    local key_path="${TF_VAR_pve_ssh_key_private/#\~/$HOME}"
    if [ -f "$key_path" ]; then
        # Check permissions
        local perms=$(stat -c %a "$key_path" 2>/dev/null || echo "")
        if [ "$perms" = "600" ] || [ "$perms" = "400" ]; then
            print_pass
        else
            print_warn
            echo "  SSH key has permissions $perms (should be 600 or 400)"
        fi
    else
        print_fail
        echo "  SSH key not found: $key_path"
    fi
}

test_terraform_validate() {
    print_test "Terraform configuration valid"
    cd "$TERRAFORM_DIR"
    if terraform validate &>/dev/null; then
        print_pass
    else
        print_fail
        terraform validate
    fi
}

test_terraform_format() {
    print_test "Terraform code formatted"
    cd "$TERRAFORM_DIR"
    if terraform fmt -check -recursive . &>/dev/null; then
        print_pass
    else
        print_warn
        echo "  Run: terraform fmt -recursive ."
    fi
}

test_checklist_file() {
    print_test "Image checklist completed"

    local missing_checksums=0
    for env in dev staging prod; do
        if grep -q "REPLACE_WITH_ACTUAL_CHECKSUM" "$TERRAFORM_DIR/environments/$env/terraform.tfvars"; then
            ((missing_checksums++))
        fi
    done

    if [ $missing_checksums -eq 0 ]; then
        print_pass
    else
        print_warn
        echo "  $missing_checksums environment(s) need image checksums updated"
    fi
}

test_proxmox_connectivity() {
    print_test "Proxmox connectivity"
    if [ ! -f "$PROJECT_DIR/.env" ]; then
        print_warn
        return
    fi

    set -a
    source "$PROJECT_DIR/.env" 2>/dev/null || true
    set +a

    if [ -z "$TF_VAR_pve_api_url" ]; then
        print_warn
        return
    fi

    # Try to ping Proxmox API
    if curl -s -k -H "Authorization: PVEAPIToken=$TF_VAR_pve_token_id=$TF_VAR_pve_token_secret" \
        "${TF_VAR_pve_api_url%/api2/json}/api2/json/version" &>/dev/null; then
        print_pass
    else
        print_fail
        echo "  Could not connect to Proxmox API at $TF_VAR_pve_api_url"
    fi
}

test_gitignore() {
    print_test ".gitignore configured"
    if grep -q "\.env" "$PROJECT_DIR/.gitignore" 2>/dev/null && \
       grep -q "terraform\.tfstate" "$PROJECT_DIR/.gitignore" 2>/dev/null; then
        print_pass
    else
        print_warn
        echo "  .gitignore may need .env and tfstate entries"
    fi
}

test_readme() {
    print_test "README.md exists"
    if [ -f "$PROJECT_DIR/README.md" ]; then
        print_pass
    else
        print_fail
    fi
}

test_documentation() {
    print_test "Documentation files exist"
    local missing=false

    for doc in ARCHITECTURE.md DEPLOYMENT.md; do
        if [ ! -f "$PROJECT_DIR/docs/$doc" ]; then
            echo "  Missing: docs/$doc"
            missing=true
        fi
    done

    if [ "$missing" = false ]; then
        print_pass
    else
        print_fail
    fi
}

# Main function
main() {
    echo "Proxmox Terraform Configuration Validator"
    echo "=========================================="
    echo ""

    # Basic checks
    echo "Basic Checks:"
    test_terraform_installed
    test_terraform_version
    test_terraform_directory
    test_terraform_files
    test_modules_exist
    test_environments_exist
    echo ""

    # File configuration
    echo "File Configuration:"
    test_env_file
    test_env_variables
    test_ssh_key
    test_gitignore
    test_readme
    test_documentation
    echo ""

    # Terraform validation
    echo "Terraform Validation:"
    test_terraform_validate
    test_terraform_format
    test_checklist_file
    echo ""

    # Connectivity
    echo "Connectivity Tests:"
    test_proxmox_connectivity
    echo ""

    # Summary
    echo "=========================================="
    echo "Validation Summary:"
    echo -e "  ${GREEN}Passed:${NC}  $PASSED"
    echo -e "  ${YELLOW}Warnings:${NC} $WARNINGS"
    echo -e "  ${RED}Failed:${NC}  $FAILED"
    echo ""

    if [ $FAILED -eq 0 ]; then
        print_success "All critical checks passed!"
        if [ $WARNINGS -gt 0 ]; then
            print_info "Please review $WARNINGS warning(s) above"
        fi
        exit 0
    else
        print_error "Please fix $FAILED critical issue(s) before deploying"
        exit 1
    fi
}

# Run main
main "$@"
