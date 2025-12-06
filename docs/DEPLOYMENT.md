# Deployment Guide

> **Note**: Documentation updated for Proxmox VE 9.1.1 compatibility. Tested with PVE 9.1+ and compatible with PVE 7/8. See [Version Notes](#version-notes) for compatibility details.

## Pre-Deployment Checklist

### Proxmox Prerequisites
- [ ] Proxmox VE >= 7.0 installed and running
- [ ] Network connectivity to Proxmox API
- [ ] Storage configured (local, local-lvm, or custom)
- [ ] Virtual network bridge configured (vmbr0 or custom)

### User & Permissions
- [ ] API token created in Proxmox:
  - User: `terraform@pve` (recommended) or `terraform@pam` (legacy)
  - Token name: `terraform-token`
  - Permissions required:
    - Datastore.AllocateSpace
    - Datastore.Audit
    - VM.Allocate
    - VM.Clone
    - VM.Config.* (all VM config permissions)
    - VM.Console
    - VM.Snapshot

### Local Machine
- [ ] Terraform >= 1.5.0 installed
- [ ] SSH key generated for Proxmox access
- [ ] Git clone of this repository
- [ ] Environment variables configured

## Step 1: Setup Proxmox API Token & Permissions

### Configuration Variables

Before setting up, note these variables you may want to customize:

```bash
# Proxmox setup variables
PROXMOX_API_HOST="pve.example.com"      # Your Proxmox host
PROXMOX_USER="terraform"                 # Username (without realm)
PROXMOX_REALM="pve"                      # Authentication realm (pve, pam, etc)
PROXMOX_GROUP="terraform-users"          # Group name
PROXMOX_TOKEN_NAME="token"               # API token name
PROXMOX_SSH_USER="root"                  # SSH user on Proxmox node
PROXMOX_ROLE_NAME="Terraform"            # Custom role name
```

### Understanding Authentication Realms

Proxmox VE uses authentication realms to determine how users are authenticated. The format for API tokens is `user@realm!tokenname=secret`.

#### Available Realms

| Realm | Full Name | Description | Use Case | User Creation |
|-------|-----------|-------------|----------|---|
| **@pve** | PVE Realm | Proxmox-internal user database (recommended) | Modern deployments, cloud/enterprise | Direct in Proxmox without system user |
| **@pam** | Linux PAM | System user authentication via Linux PAM | Legacy setups, requires system user | Must create Linux system user first |
| **@ldap** | LDAP | LDAP/Active Directory integration | Enterprise directory services | Managed by LDAP server |
| **@openid** | OpenID Connect | Federated identity management | Cloud deployments with SSO | Managed by identity provider |

#### Recommended: Using @pve Realm

For new deployments, **@pve realm is recommended** because:
- ✅ No system user required (managed by Proxmox)
- ✅ Cleaner separation of concerns
- ✅ Better for cloud/containerized environments
- ✅ Simpler to manage in web UI
- ✅ Modern Proxmox standard (PVE 6.0+)

**Format**: `terraform@pve!token=secret`

#### Legacy: Using @pam Realm

The **@pam realm is for compatibility** if you:
- Have legacy systems requiring Linux system users
- Manage authentication centrally via PAM
- Need backward compatibility with older setups

**Format**: `terraform@pam!token=secret`

**Note**: @pam requires creating a Linux system user: `useradd terraform`

#### Token Format Examples

```
# Using @pve realm (recommended)
Token ID: terraform@pve!token
Full Token: terraform@pve!token=xxxxx-xxxx-xxxx-xxxx-xxxxx

# Using @pam realm (legacy)
Token ID: terraform@pam!token
Full Token: terraform@pam!token=xxxxx-xxxx-xxxx-xxxx-xxxxx
```

### Setup Methods (Choose One)

Choose the method that works best for your workflow:

| Method | Time | Skill Level | Best For |
|--------|------|-------------|----------|
| **Option 1: Web UI** | ~5-10 min | Beginner | Prefer GUI, less command-line |
| **Option 2: Automated Script** | ~2 min | All levels | Quick setup, all automation |
| **Option 3: Manual CLI** | ~5 min | Intermediate | Understanding each step, PVE 7 |

---

### Option 1: Create API Token via Web UI (Simplest)

**If you prefer using the Proxmox web interface:**

1. Login to Proxmox web interface: `https://pve.example.com:8006`
2. Navigate to: **Datacenter** → **Permissions** → **Users**
3. Click **Add** to create a new user (if needed):
   - **User name**: `terraform`
   - **Realm**: `Linux PAM` or `PVE`
4. Navigate to: **Datacenter** → **Permissions** → **API Tokens**
5. Click **Add** button
6. Fill in:
   - **User**: Select or type `terraform@pve` (or `terraform@pam`)
   - **Token ID**: `token`
   - **Expire**: Leave empty (or set specific date)
   - **Privilege Separation**: Leave unchecked (`privsep=0`)
7. Click **Add**
8. **IMMEDIATELY COPY AND SAVE** the full token value shown (format: `username@realm!tokenname=value`)
   - This is the **only time** you'll see the secret part
9. Navigate to: **Datacenter** → **Permissions** → **Roles**
10. Click **Create** to add custom role (or use existing role)
11. Navigate to: **Datacenter** → **Permissions** → **ACL**
12. Click **Add** and assign the role to your token:
    - **Path**: `/`
    - **User/Token**: `terraform@pve!token`
    - **Role**: `Terraform` (create if needed with permissions from table below)

**If you don't want to create a role via UI, use one of the CLI options below instead.**

### Option 2: Automated Setup via CLI (PVE 8+)

**Run these commands on Proxmox node (as root):**

```bash
#!/bin/bash
# Configure these variables
PROXMOX_USER="terraform"
PROXMOX_REALM="pve"
PROXMOX_GROUP="terraform-users"
PROXMOX_TOKEN_NAME="token"
PROXMOX_ROLE_NAME="Terraform"

# Create custom role with required permissions
pveum role add $PROXMOX_ROLE_NAME -privs "Datastore.Allocate \
  Datastore.AllocateSpace Datastore.AllocateTemplate \
  Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify \
  SDN.Use VM.Allocate VM.Audit VM.Clone VM.Config.CDROM \
  VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType \
  VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate \
  VM.PowerMgmt User.Modify"

# Create group
pveum group add $PROXMOX_GROUP

# Grant permissions to group at root level (required for image downloads)
pveum acl modify / -group ${PROXMOX_GROUP} -role $PROXMOX_ROLE_NAME
pveum acl modify /sdn/zones -group ${PROXMOX_GROUP} -role $PROXMOX_ROLE_NAME
pveum acl modify /storage -group ${PROXMOX_GROUP} -role $PROXMOX_ROLE_NAME
pveum acl modify /vms -group ${PROXMOX_GROUP} -role $PROXMOX_ROLE_NAME

# Create user and add to group
pveum useradd ${PROXMOX_USER}@${PROXMOX_REALM} -groups $PROXMOX_GROUP

# Generate API token
echo "Creating API token for ${PROXMOX_USER}@${PROXMOX_REALM}..."
pveum user token add ${PROXMOX_USER}@${PROXMOX_REALM} $PROXMOX_TOKEN_NAME -privsep 0

echo "Setup complete!"
echo "Token details:"
echo "  User: ${PROXMOX_USER}@${PROXMOX_REALM}"
echo "  Token ID: ${PROXMOX_USER}@${PROXMOX_REALM}!${PROXMOX_TOKEN_NAME}"
```

### Option 3: Manual CLI Setup (PVE 7/8)

**Step 1: Create Custom Role**

1. SSH to Proxmox node as root:
```bash
ssh root@pve.example.com
```

2. Create the Terraform role with comprehensive permissions:
```bash
pveum role add Terraform -privs "Datastore.Allocate \
  Datastore.AllocateSpace Datastore.AllocateTemplate \
  Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify \
  SDN.Use VM.Allocate VM.Audit VM.Clone VM.Config.CDROM \
  VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType \
  VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate \
  VM.PowerMgmt User.Modify"
```

**Step 2: Create Group & User**

```bash
# Create group
pveum group add terraform-users

# Create user in @pve realm (Proxmox-internal, no system user required)
pveum useradd terraform@pve -groups terraform-users

# Alternative: If using @pam realm (Linux PAM, requires system user)
# First create Linux system user:
# useradd terraform
# Then create Proxmox user:
# pveum useradd terraform@pam -groups terraform-users
```

**Step 3: Grant Permissions**

These permissions are required for different operations:

```bash
# Root level - REQUIRED for cloud image downloads
pveum acl modify / -group terraform-users -role Terraform

# Storage - Required for datastore operations
pveum acl modify /storage -group terraform-users -role Terraform

# VMs - Required for VM operations
pveum acl modify /vms -group terraform-users -role Terraform

# SDN - Required for network operations (optional if not using SDN)
pveum acl modify /sdn/zones -group terraform-users -role Terraform
```

**Step 4: Generate API Token**

```bash
# Generate token for terraform@pve user
pveum user token add terraform@pve token -privsep 0

# Output will show:
# ┌─────────────────────┬─────────────────────────────────┐
# │ key                 │ value                           │
# ├─────────────────────┼─────────────────────────────────┤
# │ full-tokenid        │ terraform@pve!token             │
# │ info                │ {"expire":0,"privsep":0}        │
# │ value               │ xxxxxxxx-xxxx-xxxx-xxxx-xxxxxx  │
# └─────────────────────┴─────────────────────────────────┘

# SAVE THIS OUTPUT IMMEDIATELY! The token secret is only shown once.
```

### Required Permissions Explained

| Permission | Purpose |
|------------|---------|
| `Datastore.Allocate` | Allocate new datastore |
| `Datastore.AllocateSpace` | Allocate space in datastore |
| `Datastore.AllocateTemplate` | Upload templates to datastore (required for image downloads) |
| `Datastore.Audit` | Audit datastore access |
| `Pool.Allocate` | Create and manage pools |
| `Sys.Audit` | Audit system (required for image downloads) |
| `Sys.Console` | Access console |
| `Sys.Modify` | Modify system settings (required for image downloads) |
| `VM.Allocate` | Create new VMs |
| `VM.Audit` | Audit VM access |
| `VM.Clone` | Clone VMs |
| `VM.Config.CDROM` | Configure CDROM |
| `VM.Config.Cloudinit` | Configure cloud-init |
| `VM.Config.CPU` | Configure CPU |
| `VM.Config.Disk` | Configure disks |
| `VM.Config.HWType` | Configure hardware type |
| `VM.Config.Memory` | Configure memory |
| `VM.Config.Network` | Configure network |
| `VM.Config.Options` | Configure VM options |
| `VM.Migrate` | Migrate VMs |
| `VM.PowerMgmt` | Power management |
| `User.Modify` | Modify user permissions |

### Verify Token Creation

```bash
# List tokens for terraform user
pveum user token list terraform@pve

# Should show:
# ┌────────────────────────────┬─────────┬──────────────┐
# │ tokenid                    │ expire  │ comment      │
# ├────────────────────────────┼─────────┼──────────────┤
# │ terraform@pve!token        │ 0       │              │
# └────────────────────────────┴─────────┴──────────────┘
```

### Test API Token Access

```bash
# Test token connectivity from your local machine
PROXMOX_HOST="pve.example.com"
TOKEN_ID="terraform@pve!token"
TOKEN_SECRET="your-token-secret"

curl -s -k -X GET \
  -H "Authorization: PVEAPIToken=${TOKEN_ID}=${TOKEN_SECRET}" \
  "https://${PROXMOX_HOST}:8006/api2/json/version"

# Should return Proxmox version info
```

## Step 2: Setup SSH Access

### Generate SSH Key (if needed)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/terraform_id_ed25519 -C "terraform@proxmox"
chmod 600 ~/.ssh/terraform_id_ed25519
```

### Add Public Key to Proxmox Node

```bash
# Copy your public key
cat ~/.ssh/terraform_id_ed25519.pub

# On Proxmox node, add to authorized_keys
# SSH into your proxmox node
ssh root@pve.example.com

# Add public key
cat >> /root/.ssh/authorized_keys << 'EOF'
ssh-ed25519 AAAA... terraform@proxmox
EOF
```

### Test SSH Access

```bash
ssh -i ~/.ssh/terraform_id_ed25519 root@pve.example.com "echo 'SSH access working'"
```

## Step 3: Configure Terraform Variables

### Configuration Variables for .env File

These are the key variables you need to set based on your Proxmox setup:

```bash
# Proxmox API Configuration (from Step 1)
TF_VAR_pve_api_url="https://pve.example.com/api2/json"        # Proxmox API endpoint
TF_VAR_pve_token_id="terraform@pve!token"                     # Token ID (user@realm!tokenname)
TF_VAR_pve_token_secret="xxxxx-xxxx-xxxx-xxxx-xxxxx"          # Token secret (from pveum output)
TF_VAR_pve_user="root"                                         # SSH user on Proxmox node
TF_VAR_pve_ssh_key_private="~/.ssh/terraform_id_ed25519"      # Path to SSH private key
TF_VAR_pve_insecure="false"                                    # SSL verification (true only for self-signed)

# Proxmox Infrastructure
TF_VAR_node="pve"                                              # Proxmox node name
TF_VAR_datacenter="local"                                      # Datacenter ID
TF_VAR_storage_local="local"                                   # Local storage datastore
TF_VAR_storage_lvm="local-lvm"                                 # LVM storage datastore
TF_VAR_bridge_interface="vmbr0"                                # Network bridge interface
TF_VAR_vlan_id="1"                                             # Default VLAN ID
```

### Create Environment File

Create `.env` file in project root with your actual values:

```bash
#!/bin/bash
# .env - DO NOT COMMIT THIS FILE
# Configure these with YOUR actual values

# Proxmox API Configuration
export TF_VAR_pve_api_url="https://pve.example.com/api2/json"
export TF_VAR_pve_token_id="terraform@pve!token"
export TF_VAR_pve_token_secret="PASTE_YOUR_TOKEN_SECRET_HERE"
export TF_VAR_pve_user="root"
export TF_VAR_pve_ssh_key_private="~/.ssh/terraform_id_ed25519"
export TF_VAR_pve_insecure="false"

# Proxmox Infrastructure Configuration
export TF_VAR_node="pve"
export TF_VAR_datacenter="local"
export TF_VAR_storage_local="local"
export TF_VAR_storage_lvm="local-lvm"
export TF_VAR_bridge_interface="vmbr0"
export TF_VAR_vlan_id="1"

# Optional: Enable debug logging
# export TF_LOG="DEBUG"
```

### Variable Reference

| Variable | Required | Example | Description |
|----------|----------|---------|-------------|
| `TF_VAR_pve_api_url` | Yes | `https://pve.example.com/api2/json` | Proxmox API endpoint URL |
| `TF_VAR_pve_token_id` | Yes | `terraform@pve!token` | API token ID (format: user@realm!tokenname) |
| `TF_VAR_pve_token_secret` | Yes | `xxxxx-xxxx-xxxx` | API token secret (save immediately after generation) |
| `TF_VAR_pve_user` | Yes | `root` | SSH user for Proxmox node access |
| `TF_VAR_pve_ssh_key_private` | Yes | `~/.ssh/terraform_id_ed25519` | Path to SSH private key |
| `TF_VAR_pve_insecure` | No | `false` | Disable SSL verification (only for self-signed certs) |
| `TF_VAR_node` | Yes | `pve` | Proxmox node name (visible in web UI) |
| `TF_VAR_datacenter` | No | `local` | Datacenter ID |
| `TF_VAR_storage_local` | No | `local` | Local storage datastore for ISOs |
| `TF_VAR_storage_lvm` | No | `local-lvm` | LVM storage datastore for VM disks |
| `TF_VAR_bridge_interface` | No | `vmbr0` | Network bridge interface name |
| `TF_VAR_vlan_id` | No | `1` | Default VLAN ID |

### Add to .gitignore

```bash
# Append to .gitignore
echo ".env" >> .gitignore
echo "terraform/.terraform/" >> .gitignore
echo "terraform/terraform.tfstate*" >> .gitignore
echo "*.backup" >> .gitignore
```

### Load Environment Variables

```bash
source .env
```

## Step 4: Prepare Cloud Images

### Get Image Checksum

Before deploying, get the checksum for your chosen image.

**For Debian:**
```bash
curl -s https://cloud.debian.org/images/cloud/bookworm/latest/SHA512SUMS | \
  grep debian-12-generic-amd64.qcow2
```

**For Ubuntu:**
```bash
curl -s https://cloud-images.ubuntu.com/releases/jammy/release-latest/SHA256SUMS | \
  grep ubuntu-22.04-server-cloudimg-amd64.img
```

### Update Environment Configuration

Edit `terraform/environments/dev/terraform.tfvars`:

```hcl
image_checksum = "ACTUAL_CHECKSUM_VALUE_HERE"
# (paste actual checksum, not placeholder)
```

Repeat for staging and prod environments.

## Step 5: Initialize and Validate

### Navigate to Terraform Directory

```bash
cd terraform
```

### Initialize Terraform

```bash
terraform init
```

Expected output:
```
Initializing the backend...
Initializing provider plugins...
Terraform has been successfully configured!
```

### Validate Configuration

```bash
terraform validate
```

Expected output:
```
Success! The configuration is valid.
```

### Format Check (optional)

```bash
terraform fmt -check

# Auto-format if needed
terraform fmt -recursive
```

## Step 6: Plan Deployment

### Plan Development Environment

```bash
terraform plan -var-file=environments/dev/terraform.tfvars -out=dev.plan
```

Review the output:
- Should show creation of template resources
- No errors about authentication
- Plan file saved as `dev.plan`

### Example Plan Output

```
Terraform will perform the following actions:

  # module.template[0].proxmox_virtual_environment_download_file.image will be created
  + resource "proxmox_virtual_environment_download_file" "image" {
      + checksum           = "..."
      + checksum_algorithm = "sha256"
      + content_type       = "iso"
      + datastore_id       = "local"
      + file_name          = "debian-12-generic-amd64.img"
      + id                 = (known after apply)
      + node_name          = "pve"
      + url                = "https://..."
    }

  # module.template[0].proxmox_virtual_environment_vm.template will be created
  + resource "proxmox_virtual_environment_vm" "template" {
      + bios                = "seabios"
      + id                  = (known after apply)
      + machine             = "q35"
      + name                = "debian-12-template"
      + node_name           = "pve"
      + started             = false
      + template            = true
      + vm_id               = 9000
      ...
    }

Plan: 3 to add, 0 to change, 0 to destroy.

Saved the plan to: dev.plan
```

## Step 7: Apply Configuration

### Deploy Development Environment

```bash
terraform apply dev.plan
```

### Monitor Deployment

The deployment will:
1. Download the cloud image (may take a few minutes)
2. Create cloud-init configuration
3. Create and configure VM template
4. Mark VM as template (not started)

Expected duration: 5-15 minutes depending on image size and network speed

### Verify Deployment

Check Proxmox web UI:
1. Go to: Datacenter → Virtual Machines
2. Look for "debian-12-template" VM
3. Verify it's marked as template (icon shows template)
4. Verify it's not running (stopped state)

Verify with Terraform:
```bash
terraform show
terraform state list
terraform output
```

## Step 8: Deploy VMs from Template

### Enable VM Creation

Edit `terraform/environments/staging/terraform.tfvars`:

```hcl
create_template = true
create_vms      = true    # Enable VM creation
create_lxc      = false
```

### Plan VM Deployment

```bash
terraform plan -var-file=environments/staging/terraform.tfvars
```

### Apply VM Deployment

```bash
terraform apply -var-file=environments/staging/terraform.tfvars
```

### Verify VM Creation

- Check Proxmox web UI for new VMs
- SSH into VM using cloud-init user:
```bash
ssh -i <private-key> debian@<vm-ip>
```

## Step 9: Deploy LXC Containers

### Enable LXC Creation

Edit `terraform/environments/prod/terraform.tfvars`:

```hcl
create_template = true
create_vms      = true
create_lxc      = true    # Enable LXC creation
```

### Plan LXC Deployment

```bash
terraform plan -var-file=environments/prod/terraform.tfvars
```

### Apply LXC Deployment

```bash
terraform apply -var-file=environments/prod/terraform.tfvars
```

## Troubleshooting Deployment

### Error: "API Token not valid"

**Solution:**
```bash
# Verify token format (should be user@realm!tokenname=secret)
echo "User: terraform@pve!terraform-token"
echo "Secret: ${TF_VAR_pve_token_secret}"

# Check in Proxmox web UI:
# Datacenter → Permissions → API Tokens
```

### Error: "Storage not found"

**Solution:**
```bash
# Verify storage exists
pvesh get /storage

# Check terraform variable
grep storage_local terraform/environments/dev/terraform.tfvars
grep storage_lvm terraform/environments/dev/terraform.tfvars
```

### Error: "SSH key permission denied"

**Solution:**
```bash
# Check SSH key permissions
chmod 600 ~/.ssh/terraform_id_ed25519
chmod 700 ~/.ssh

# Verify public key on Proxmox
ssh-keygen -y -f ~/.ssh/terraform_id_ed25519 > ~/.ssh/terraform_id_ed25519.pub

# Test SSH
ssh -i ~/.ssh/terraform_id_ed25519 root@pve.example.com "hostname"
```

### Error: "Image download timeout"

**Solution:**
```bash
# Check image URL is accessible
curl -I https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2

# Increase timeout in Proxmox if needed
# Proxmox → Datacenter → Options → Download timeout
```

### Deployment Hangs

**Solution:**
1. Check Proxmox task logs: Web UI → Datacenter → Tasks
2. Check Terraform logs: `TF_LOG=DEBUG terraform apply`
3. Check Proxmox node resources (CPU, memory, disk)
4. Check network connectivity between Terraform and Proxmox

## Post-Deployment

### Verify Resources

```bash
# List all resources created
terraform state list

# Show specific resource details
terraform show module.template

# View outputs
terraform output
```

### Connect to Resources

**Connect to VM:**
```bash
ssh -i <ssh-key> debian@<vm-ip>
```

**Connect to LXC Container:**
```bash
ssh -i <ssh-key> root@<container-ip>
# or via Proxmox console
```

### Next Steps

1. **Configure Monitoring**: Setup monitoring for created resources
2. **Setup Backups**: Configure Proxmox backup policies
3. **Document Infrastructure**: Update your infrastructure documentation
4. **Commit Configuration**: Commit to version control
5. **Setup CI/CD**: Integrate with CI/CD pipeline for automated deployments

## Rollback Procedure

### Rollback Last Deployment

```bash
# Check git history
git log --oneline

# Revert to previous state
git checkout <previous-commit>

# Refresh Terraform
terraform refresh -var-file=environments/dev/terraform.tfvars

# Apply previous configuration
terraform apply -var-file=environments/dev/terraform.tfvars
```

### Emergency Destroy

```bash
# Destroy specific resource
terraform destroy -target=module.vm -var-file=environments/staging/terraform.tfvars

# Destroy entire environment
terraform destroy -var-file=environments/dev/terraform.tfvars
```

## Maintenance

### Regular Tasks

- **Weekly**: Review Terraform state for drift
- **Monthly**: Update cloud image checksums
- **Quarterly**: Test disaster recovery
- **Quarterly**: Review and optimize resource allocation

## Version Notes

### Proxmox VE 9.1.1+ Compatibility

Documentation has been updated for full compatibility with Proxmox VE 9.1.1+ with the following important notes:

#### Permission Changes in PVE 9

- **Removed**: `VM.Monitor` permission (was deprecated and removed in Proxmox VE 9.0+)
  - This permission is no longer valid in PVE 9.x
  - Documentation has been updated to exclude this permission
  - If you're upgrading from PVE 8, you may see warnings about this permission - they can be safely ignored

#### Backward Compatibility

- **PVE 7/8**: The documentation and setup scripts are backward compatible with Proxmox VE 7.x and 8.x
- **PVE 9.x**: Full support for PVE 9.0, 9.1, and later versions
- All CLI commands (pveum) remain the same across versions
- Web UI navigation paths are consistent across PVE 7-9

#### Verified CLI Commands

All pveum commands have been verified to work on PVE 9.1.1:
- `pveum role add` ✓
- `pveum group add` ✓
- `pveum useradd` / `pveum user add` ✓
- `pveum user token add` ✓
- `pveum acl modify` ✓

#### API Token Format

Token format remains unchanged:
- Full token ID: `user@realm!tokenname`
- Authorization header: `PVEAPIToken=user@realm!tokenname=secret`
- Effective from PVE 7.0 through PVE 9.1.1+

### Testing Confirmation

Documentation has been tested and verified for compatibility with:
- ✓ Proxmox VE 9.1.1
- ✓ Proxmox VE 8.x (backward compatible)
- ✓ Proxmox VE 7.x (backward compatible)
