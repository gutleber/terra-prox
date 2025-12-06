#!/bin/bash

# setup-proxmox.sh - Interactive Proxmox user and permission setup
# This script creates the necessary Proxmox user, group, role, and API token
# for Terraform to manage infrastructure
#
# Usage: ./setup-proxmox.sh [--non-interactive]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
PROXMOX_USER="terraform"
PROXMOX_REALM="pve"
PROXMOX_GROUP="terraform-users"
PROXMOX_TOKEN_NAME="token"
PROXMOX_ROLE_NAME="Terraform"
INTERACTIVE=true

# Parse arguments
if [[ "$1" == "--non-interactive" ]]; then
  INTERACTIVE=false
fi

print_header() {
  echo -e "${BLUE}=== $1 ===${NC}"
}

print_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on Proxmox
check_proxmox() {
  if ! command -v pveum &> /dev/null; then
    print_error "This script must be run on Proxmox VE node"
    print_error "pveum command not found"
    exit 1
  fi
}

# Interactive setup
interactive_setup() {
  print_header "Proxmox Terraform Setup Configuration"
  echo ""

  read -p "Terraform username [${PROXMOX_USER}]: " input
  PROXMOX_USER="${input:-$PROXMOX_USER}"

  read -p "Authentication realm (pve/pam/ldap) [${PROXMOX_REALM}]: " input
  PROXMOX_REALM="${input:-$PROXMOX_REALM}"

  read -p "Group name [${PROXMOX_GROUP}]: " input
  PROXMOX_GROUP="${input:-$PROXMOX_GROUP}"

  read -p "API token name [${PROXMOX_TOKEN_NAME}]: " input
  PROXMOX_TOKEN_NAME="${input:-$PROXMOX_TOKEN_NAME}"

  read -p "Custom role name [${PROXMOX_ROLE_NAME}]: " input
  PROXMOX_ROLE_NAME="${input:-$PROXMOX_ROLE_NAME}"

  echo ""
  print_info "Configuration summary:"
  echo "  Username: ${PROXMOX_USER}@${PROXMOX_REALM}"
  echo "  Group: ${PROXMOX_GROUP}"
  echo "  Token: ${PROXMOX_USER}@${PROXMOX_REALM}!${PROXMOX_TOKEN_NAME}"
  echo "  Role: ${PROXMOX_ROLE_NAME}"
  echo ""

  read -p "Continue with setup? (yes/no) [yes]: " confirm
  if [[ "${confirm,,}" == "no" ]]; then
    print_warning "Setup cancelled"
    exit 0
  fi
}

# Create role
create_role() {
  print_header "Creating Custom Role"

  if pveum role list | grep -q "^${PROXMOX_ROLE_NAME}$"; then
    print_warning "Role '${PROXMOX_ROLE_NAME}' already exists, skipping"
    return
  fi

  print_info "Creating role with comprehensive permissions..."
  pveum role add "${PROXMOX_ROLE_NAME}" -privs "Datastore.Allocate \
    Datastore.AllocateSpace Datastore.AllocateTemplate \
    Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify \
    SDN.Use VM.Allocate VM.Audit VM.Clone VM.Config.CDROM \
    VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType \
    VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate \
    VM.PowerMgmt User.Modify"

  print_success "Role '${PROXMOX_ROLE_NAME}' created"
}

# Create group
create_group() {
  print_header "Creating User Group"

  if pveum group list | grep -q "^${PROXMOX_GROUP}$"; then
    print_warning "Group '${PROXMOX_GROUP}' already exists, skipping"
    return
  fi

  print_info "Creating group '${PROXMOX_GROUP}'..."
  pveum group add "${PROXMOX_GROUP}"

  print_success "Group '${PROXMOX_GROUP}' created"
}

# Create user
create_user() {
  print_header "Creating User"

  USER_FULL="${PROXMOX_USER}@${PROXMOX_REALM}"

  if pveum user list | grep -q "^${USER_FULL}$"; then
    print_warning "User '${USER_FULL}' already exists, skipping"
    return
  fi

  print_info "Creating user '${USER_FULL}'..."
  pveum useradd "${USER_FULL}" -groups "${PROXMOX_GROUP}"

  print_success "User '${USER_FULL}' created and added to '${PROXMOX_GROUP}'"
}

# Grant permissions
grant_permissions() {
  print_header "Granting Permissions"

  print_info "Granting permissions to group '${PROXMOX_GROUP}'..."

  # Root level (REQUIRED for image downloads)
  pveum acl modify / -group "${PROXMOX_GROUP}" -role "${PROXMOX_ROLE_NAME}"
  print_success "Root (/) - granted"

  # Storage
  pveum acl modify /storage -group "${PROXMOX_GROUP}" -role "${PROXMOX_ROLE_NAME}"
  print_success "/storage - granted"

  # VMs
  pveum acl modify /vms -group "${PROXMOX_GROUP}" -role "${PROXMOX_ROLE_NAME}"
  print_success "/vms - granted"

  # SDN (optional)
  pveum acl modify /sdn/zones -group "${PROXMOX_GROUP}" -role "${PROXMOX_ROLE_NAME}"
  print_success "/sdn/zones - granted"
}

# Create API token
create_token() {
  print_header "Creating API Token"

  USER_FULL="${PROXMOX_USER}@${PROXMOX_REALM}"

  print_info "Creating API token for user '${USER_FULL}'..."
  echo ""
  echo -e "${YELLOW}IMPORTANT: Save the token value immediately!${NC}"
  echo -e "${YELLOW}The secret is only displayed once.${NC}"
  echo ""

  pveum user token add "${USER_FULL}" "${PROXMOX_TOKEN_NAME}" -privsep 0

  echo ""
  print_success "API token created"
  echo ""
  print_header "Next Steps"
  echo "1. Create .env file in project root with:"
  echo "   export TF_VAR_pve_api_url=\"https://your-proxmox-host/api2/json\""
  echo "   export TF_VAR_pve_token_id=\"${USER_FULL}!${PROXMOX_TOKEN_NAME}\""
  echo "   export TF_VAR_pve_token_secret=\"<PASTE_TOKEN_VALUE_HERE>\""
  echo "   export TF_VAR_pve_user=\"root\""
  echo "   export TF_VAR_pve_ssh_key_private=\"~/.ssh/terraform_id_ed25519\""
  echo ""
  echo "2. Source the .env file:"
  echo "   source .env"
  echo ""
  echo "3. Run Terraform:"
  echo "   cd terraform && terraform init"
  echo "   make plan-dev"
  echo ""
}

# Verify setup
verify_setup() {
  print_header "Verifying Setup"

  USER_FULL="${PROXMOX_USER}@${PROXMOX_REALM}"

  # Check role
  if pveum role list | grep -q "^${PROXMOX_ROLE_NAME}$"; then
    print_success "Role '${PROXMOX_ROLE_NAME}' exists"
  else
    print_error "Role '${PROXMOX_ROLE_NAME}' not found"
    return 1
  fi

  # Check group
  if pveum group list | grep -q "^${PROXMOX_GROUP}$"; then
    print_success "Group '${PROXMOX_GROUP}' exists"
  else
    print_error "Group '${PROXMOX_GROUP}' not found"
    return 1
  fi

  # Check user
  if pveum user list | grep -q "^${USER_FULL}$"; then
    print_success "User '${USER_FULL}' exists"
  else
    print_error "User '${USER_FULL}' not found"
    return 1
  fi

  # Check token
  if pveum user token list "${USER_FULL}" | grep -q "${PROXMOX_TOKEN_NAME}"; then
    print_success "API token '${PROXMOX_TOKEN_NAME}' exists"
  else
    print_error "API token '${PROXMOX_TOKEN_NAME}' not found"
    return 1
  fi

  return 0
}

# Main execution
main() {
  echo ""
  print_header "Proxmox Terraform Setup Script"
  echo "This script will configure Proxmox for Terraform management"
  echo ""

  check_proxmox

  if [[ "$INTERACTIVE" == "true" ]]; then
    interactive_setup
  else
    print_info "Running in non-interactive mode with default values"
  fi

  create_role
  create_group
  create_user
  grant_permissions
  create_token

  echo ""
  if verify_setup; then
    print_success "Setup completed successfully!"
  else
    print_warning "Setup completed with some warnings - please verify manually"
  fi

  echo ""
}

# Run main function
main "$@"
