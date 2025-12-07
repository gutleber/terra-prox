# Proxmox Setup & Configuration Summary

> **Updated for Proxmox VE 9.1.1**: This document has been verified for compatibility with Proxmox VE 9.1.1 and is backward compatible with PVE 7/8. Key change: `VM.Monitor` permission was removed in PVE 9.0+.

## Overview

This document summarizes all configuration variables, permission requirements, and setup procedures for Terraform to work with Proxmox VE.

## Configuration Variables

### Environment Variables (.env file)

All Terraform variables are configured via environment variables. Here's the complete reference:

#### Required Authentication Variables
```bash
export TF_VAR_pve_api_url="https://pve.example.com/api2/json"
export TF_VAR_pve_token_id="terraform@pve!token"
export TF_VAR_pve_token_secret="xxxxx-xxxx-xxxx-xxxx-xxxxx"
export TF_VAR_pve_user="root"
export TF_VAR_pve_ssh_key_private="~/.ssh/id_ed25519_ditec_root_terraform"
```

#### Optional Infrastructure Variables
```bash
export TF_VAR_pve_insecure="false"
export TF_VAR_node="pve"
export TF_VAR_datacenter="local"
export TF_VAR_storage_local="local"
export TF_VAR_storage_lvm="local-lvm"
export TF_VAR_bridge_interface="vmbr0"
export TF_VAR_vlan_id="1"
```

### Environment Configuration Files (tfvars)

Each environment (dev, staging, prod) defines its own resources:

#### Template Variables (per template)
- `vm_id` - Unique VM ID
- `image_url` - Cloud image URL
- `image_filename` - Filename for downloaded image
- `image_checksum` - Image checksum for verification
- `image_checksum_algorithm` - Checksum algorithm (sha256, sha512)
- `bios` - BIOS type (seabios, ovmf)
- `cores` - CPU cores
- `memory` - RAM in MB
- `disk_size` - Disk size in GB

#### VM Configuration Variables (per VM)
- `name` - VM name (must be unique)
- `template` - Reference to template key
- `vm_id` - Unique VM ID
- `cores` - CPU cores
- `memory` - RAM in MB
- `disk_size` - OS disk size in GB
- `autostart` - Start on boot (boolean)
- `enable_cloud_init` - Enable cloud-init (boolean)
- `cloud_init_user` - Default user (debian, ubuntu, root)
- `ssh_public_keys` - SSH keys list
- `network_devices` - Network configuration
- `ip_configs` - IP address configuration
- `additional_disks` - Additional storage devices
- `enable_firewall` - Enable firewall rules (boolean)
- `firewall_rules` - List of firewall rules
- `tags` - Resource tags

#### LXC Container Variables (per container)
- `name` - Container name
- `container_id` - Unique container ID
- `os_type` - OS type (debian, ubuntu, alpine, alma, rocky)
- `os_version` - OS version
- `storage` - Storage datastore
- `disk_size` - Disk size in GB
- `cores` - CPU cores
- `memory` - RAM in MB
- `memory_swap` - Swap RAM in MB
- `autostart` - Start on boot (boolean)
- `unprivileged` - Unprivileged mode (boolean)
- `network_devices` - Network configuration
- `dns_servers` - DNS servers list
- `ssh_public_keys` - SSH keys list
- `enable_firewall` - Enable firewall rules (boolean)
- `firewall_rules` - List of firewall rules
- `tags` - Resource tags

## Proxmox API Token - Permission Requirements

### Required Permissions by Feature

| Feature | Permission | Scope | Purpose |
|---------|-----------|-------|---------|
| **Image Download** | `Datastore.AllocateTemplate` | `/` | Upload cloud images to datastore |
| **Image Download** | `Sys.Audit` | `/` | Access system audit logs |
| **Image Download** | `Sys.Modify` | `/` | Modify system settings |
| **VM Creation** | `VM.Allocate` | `/vms` | Create new VMs |
| **VM Cloning** | `VM.Clone` | `/vms` | Clone from templates |
| **VM Config** | `VM.Config.CPU` | `/vms` | Configure CPU settings |
| **VM Config** | `VM.Config.Disk` | `/vms` | Configure disks |
| **VM Config** | `VM.Config.Memory` | `/vms` | Configure memory |
| **VM Config** | `VM.Config.Network` | `/vms` | Configure network |
| **VM Config** | `VM.Config.Cloudinit` | `/vms` | Configure cloud-init |
| **Firewall** | `VM.Config.Options` | `/vms` | Configure VM options (firewall) |
| **Storage** | `Datastore.Allocate` | `/storage` | Allocate storage space |
| **Storage** | `Datastore.AllocateSpace` | `/storage` | Allocate datastore space |

### Complete Role Definition

```bash
# Terraform Role with all required permissions
pveum role add Terraform -privs "Datastore.Allocate \
  Datastore.AllocateSpace Datastore.AllocateTemplate \
  Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify \
  SDN.Use VM.Allocate VM.Audit VM.Clone VM.Config.CDROM \
  VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType \
  VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate \
  VM.PowerMgmt User.Modify"
```

### Permission Setup

```bash
# Root level (CRITICAL for image downloads)
pveum acl modify / -group terraform-users -role Terraform

# Storage operations
pveum acl modify /storage -group terraform-users -role Terraform

# VM operations
pveum acl modify /vms -group terraform-users -role Terraform

# Network operations (SDN - optional)
pveum acl modify /sdn/zones -group terraform-users -role Terraform
```

## Setup Methods

### Method 1: Automated Setup Script (Recommended)

```bash
# Make script executable
chmod +x scripts/setup-proxmox.sh

# Run from Proxmox node (as root)
./scripts/setup-proxmox.sh

# Non-interactive mode (use defaults)
./scripts/setup-proxmox.sh --non-interactive
```

**What the script does:**
1. Creates custom "Terraform" role with all required permissions
2. Creates "terraform-users" group
3. Creates "terraform" user and adds to group
4. Grants all necessary permissions
5. Generates API token
6. Verifies setup

### Method 2: Manual Setup Commands

**Step 1: Create Role**
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
pveum group add terraform-users
pveum useradd terraform@pve -groups terraform-users
```

**Step 3: Grant Permissions**
```bash
pveum acl modify / -group terraform-users -role Terraform
pveum acl modify /sdn/zones -group terraform-users -role Terraform
pveum acl modify /storage -group terraform-users -role Terraform
pveum acl modify /vms -group terraform-users -role Terraform
```

**Step 4: Generate Token**
```bash
pveum user token add terraform@pve token -privsep 0
```

### Method 3: Web UI Setup

1. Login to Proxmox web interface
2. Create custom role at **Datacenter → Permissions → Roles**
3. Create group at **Datacenter → Permissions → Groups**
4. Create user at **Datacenter → Permissions → Users**
5. Assign role permissions at **Datacenter → Permissions → ACL**
6. Generate token at **Datacenter → Permissions → API Tokens**

## Variable Customization Examples

### Custom Proxmox Setup
```bash
# If your setup uses different values:
export TF_VAR_node="pve2"                    # Different node name
export TF_VAR_storage_lvm="nvme-storage"     # NVMe datastore
export TF_VAR_bridge_interface="vmbr100"     # Different bridge
export TF_VAR_vlan_id="100"                  # Different VLAN
```

### Custom Image Locations
```hcl
# In environments/prod/terraform.tfvars
templates = {
  "centos-stream" = {
    vm_id                    = 9010
    image_url                = "https://cloud.centos.org/centos/..."
    image_filename           = "CentOS-Stream.qcow2"
    image_checksum           = "..."
    image_checksum_algorithm = "sha256"
    # ...
  }
}
```

### Custom Network Setup
```hcl
# In VM configuration
network_devices = [
  {
    bridge  = "vmbr0"
    vlan_id = 100
  },
  {
    bridge  = "vmbr1"
    vlan_id = 200
  }
]

ip_configs = [
  {
    ipv4_address = "192.168.100.10/24"
    ipv4_gateway = "192.168.100.1"
    ipv6_address = "2001:db8::10/64"
    ipv6_gateway = "2001:db8::1"
  }
]
```

## Verification

### Test Token Access
```bash
curl -s -k -H "Authorization: PVEAPIToken=terraform@pve!token=<secret>" \
  "https://pve.example.com:8006/api2/json/version"
```

### Test SSH Access
```bash
ssh -i ~/.ssh/id_ed25519_ditec_root_terraform root@pve.example.com "hostname"
```

### Verify Terraform Setup
```bash
cd terraform
terraform init
terraform validate
terraform fmt -check
bash ./scripts/validate.sh
```

## Troubleshooting

### Token Issues
```bash
# List tokens for user
pveum user token list terraform@pve

# Delete old token
pveum user token remove terraform@pve token

# Create new token
pveum user token add terraform@pve token -privsep 0
```

### Permission Issues
```bash
# List all ACL permissions
pveum acl list

# Check user permissions
pveum user permissions terraform@pve

# Verify role permissions
pveum role info Terraform
```

### SSH Issues
```bash
# Check SSH key permissions
ls -la ~/.ssh/id_ed25519_ditec_root_terraform
chmod 600 ~/.ssh/id_ed25519_ditec_root_terraform

# Test SSH connection with verbose output
ssh -vvv -i ~/.ssh/id_ed25519_ditec_root_terraform root@pve.example.com
```

## Security Best Practices

1. **Never commit .env file to git**
   - Add to .gitignore
   - Use environment variables or secret managers

2. **Use SSH keys, not passwords**
   - Generate ed25519 keys
   - Set proper file permissions (600)

3. **Use API tokens, not passwords**
   - Generate tokens with minimal required permissions
   - Rotate tokens periodically

4. **Limit API token scope**
   - Use `privsep=0` for privilege separation
   - Grant only necessary permissions

5. **Monitor token usage**
   - Check Proxmox audit logs
   - Review API access logs

6. **Use VLANs and firewall rules**
   - Isolate resources by environment
   - Configure per-VM firewall rules
   - Use network segmentation

## References

- [Terraform Proxmox Provider Documentation](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
- [Proxmox VE Permissions Documentation](https://pve.proxmox.com/wiki/Manual:_Users)
- [Proxmox VE API Documentation](https://pve.proxmox.com/pve-docs/api-viewer/)
