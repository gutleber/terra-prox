# Quick Reference Guide

## Setup (First Time)

```bash
# 1. Clone repository
git clone <repository-url>
cd terraform-vm-proxmox

# 2. Create .env with Proxmox credentials
cat > .env << 'EOF'
export TF_VAR_pve_api_url="https://pve.example.com/api2/json"
export TF_VAR_pve_token_id="terraform@pve!token_name"
export TF_VAR_pve_token_secret="your_token_secret"
export TF_VAR_pve_user="root"
export TF_VAR_pve_ssh_key_private="~/.ssh/terraform_id_ed25519"
EOF

# 3. Load environment
source .env

# 4. Validate setup
bash scripts/validate.sh

# 5. Initialize
cd terraform && terraform init
```

## Common Operations

### Deploy Development Environment (2 templates, 2 VMs, 1 LXC)

```bash
# Plan and review changes
make plan-dev

# Apply deployment
make apply-dev

# View created resources
terraform output
```

### Deploy Staging Environment (Production-like setup)

```bash
# Plan (web, app, db servers + monitoring)
make plan-staging

# Apply
make apply-staging

# See output with all resource IPs
terraform output vms_summary
terraform output lxc_containers_summary
```

### Deploy Full Production Environment

```bash
# Plan (load balancer, web, app, databases, monitoring, logging, backup)
make plan-prod

# Apply with confirmation
make apply-prod

# Get detailed infrastructure summary
terraform output infrastructure_summary

# See all created VMs with details
terraform output vms_created
```

### Add a New VM to Existing Environment

Edit `environments/staging/terraform.tfvars` and add to `vm_configs`:

```hcl
{
  name             = "new-vm-name"
  template         = "debian12"        # Reference existing template
  vm_id            = 103               # Unique ID
  cores            = 4
  memory           = 4096
  disk_size        = 50
  autostart        = true
  enable_cloud_init = true
  cloud_init_user  = "debian"

  network_devices = [{
    bridge  = "vmbr0"
    vlan_id = 2
  }]

  ip_configs = [{
    ipv4_address = "192.168.2.100/24"
    ipv4_gateway = "192.168.2.1"
  }]

  additional_disks = []
  enable_firewall  = false
  firewall_rules   = []
  tags            = ["staging"]
}
```

Then deploy:
```bash
make plan-staging
make apply-staging
```

### View All Resources Created

```bash
cd terraform

# List all resources
terraform state list

# Get summary
terraform output infrastructure_summary

# Detailed VM information
terraform output vms_created

# All container information
terraform output lxc_containers_created

# Just IPs for quick reference
terraform output vms_summary
terraform output lxc_containers_summary
```

### Connect to a Specific VM

```bash
# Get all VMs with their IPs
terraform output vms_created

# SSH to specific VM
ssh -i ~/.ssh/terraform_id_ed25519 ubuntu@192.168.10.20
```

### Connect to a Container

```bash
# Get container IPs
terraform output lxc_containers_created

# SSH to container
ssh -i ~/.ssh/terraform_id_ed25519 root@<container-ip>
```

## Troubleshooting

### Validation Errors

```bash
# Run validation script
bash scripts/validate.sh

# Check Terraform format
terraform fmt -check

# Validate configuration
cd terraform && terraform validate
```

### Authentication Issues

```bash
# Verify credentials in .env
cat .env

# Test API token
curl -s -k -H "Authorization: PVEAPIToken=$TF_VAR_pve_token_id=$TF_VAR_pve_token_secret" \
  "${TF_VAR_pve_api_url%/api2/json}/api2/json/version" | jq .
```

### SSH Connection Issues

```bash
# Test SSH access
ssh -i ~/.ssh/terraform_id_ed25519 root@pve.example.com "hostname"

# Check permissions
ls -la ~/.ssh/terraform_id_ed25519
# Should be: -rw------- (600)
```

### Terraform State Issues

```bash
# Refresh state
terraform refresh

# View current state
terraform state show module.template

# Remove corrupted resource
terraform state rm module.vm[0]
```

## Configuration Examples

### Adding a Custom Template

Add to `templates` in your environment's tfvars:

```hcl
templates = {
  "custom-os" = {
    vm_id                    = 9010
    image_url                = "https://..."
    image_filename           = "custom.qcow2"
    image_checksum           = "xyz123..."
    image_checksum_algorithm = "sha256"
    bios                     = "seabios"
    cores                    = 4
    memory                   = 8192
    disk_size                = 100
  }
}
```

### Creating a VM with Static IP and Firewall

```hcl
vm_configs = [
  {
    name             = "secure-app"
    template         = "debian12"
    vm_id            = 150
    cores            = 4
    memory           = 4096
    disk_size        = 50
    autostart        = true

    network_devices = [{
      bridge  = "vmbr0"
      vlan_id = 10
    }]

    ip_configs = [{
      ipv4_address = "192.168.10.50/24"
      ipv4_gateway = "192.168.10.1"
      ipv6_address = "2001:db8::50/64"
      ipv6_gateway = "2001:db8::1"
    }]

    additional_disks = [{
      datastore_id = "local-lvm"
      interface    = "scsi1"
      size         = 500
      ssd          = true
    }]

    enable_firewall = true
    firewall_rules = [
      {
        action    = "ACCEPT"
        direction = "IN"
        protocol  = "tcp"
        port      = "443"
        comment   = "HTTPS"
      }
    ]

    tags = ["prod", "secure"]
  }
]
```

### Creating an LXC Container

```hcl
lxc_configs = [
  {
    name           = "cache-server"
    container_id   = 300
    os_type        = "alpine"
    os_version     = "3.18"
    cores          = 2
    memory         = 1024
    disk_size      = 50
    autostart      = true
    unprivileged   = true

    network_devices = [{
      name    = "eth0"
      bridge  = "vmbr0"
      vlan_id = 10
    }]

    dns_servers = ["8.8.8.8"]

    enable_firewall = true
    firewall_rules = [
      {
        action    = "ACCEPT"
        direction = "IN"
        protocol  = "tcp"
        port      = "6379"
        source    = "192.168.10.0/24"
        comment   = "Redis"
      }
    ]

    tags = ["cache"]
  }
]
```

## Module Documentation

### Template Module
- **Location**: `terraform/modules/template/`
- **Purpose**: Create reusable VM template
- **Outputs**: `vm_id`, `vm_name`, `template_id`
- **Key Variables**: `image_url`, `image_checksum`, `vm_id`

### VM Module
- **Location**: `terraform/modules/vm/`
- **Purpose**: Clone VMs from template
- **Outputs**: `vm_id`, `vm_name`, `ip_address`
- **Key Variables**: `template_vm_id`, `vm_id`, `vm_name`

### LXC Module
- **Location**: `terraform/modules/lxc/`
- **Purpose**: Create LXC containers
- **Outputs**: `container_id`, `container_name`, `ip_address`
- **Key Variables**: `container_id`, `os_type`, `os_version`

## File Locations

```
terraform-vm-proxmox/
├── terraform/
│   ├── providers.tf              # Provider config
│   ├── variables.tf              # Global variables
│   ├── main.tf                   # Orchestration
│   ├── modules/                  # Reusable modules
│   ├── environments/              # Environment configs
│   │   ├── dev/terraform.tfvars
│   │   ├── staging/terraform.tfvars
│   │   └── prod/terraform.tfvars
│   └── .terraform/               # Provider cache (generated)
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DEPLOYMENT.md
│   └── QUICK_REFERENCE.md
├── scripts/
│   ├── deploy.sh
│   └── validate.sh
├── .env                          # Credentials (don't commit)
├── .gitignore
├── Makefile
└── README.md
```

## Using Deploy Script

```bash
# Initialize
bash scripts/deploy.sh dev init

# Plan
bash scripts/deploy.sh dev plan

# Apply
bash scripts/deploy.sh dev apply

# Destroy
bash scripts/deploy.sh dev destroy
```

## Using Make

```bash
# Help
make

# Validate
make validate

# Format
make fmt

# Development
make plan-dev
make apply-dev
make destroy-dev

# Staging
make plan-staging
make apply-staging
make destroy-staging

# Production
make plan-prod
make apply-prod
make destroy-prod
```

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `TF_VAR_pve_api_url` | Proxmox API endpoint |
| `TF_VAR_pve_token_id` | API token ID |
| `TF_VAR_pve_token_secret` | API token secret |
| `TF_VAR_pve_user` | SSH user (usually root) |
| `TF_VAR_pve_ssh_key_private` | Path to SSH private key |
| `TF_LOG` | Terraform log level (DEBUG, INFO, etc.) |

## Useful Commands

```bash
# List all resources
terraform state list

# Show resource details
terraform show module.template

# Show outputs
terraform output

# Format code
terraform fmt -recursive

# Validate syntax
terraform validate

# Check for drift
terraform refresh

# Cleanup state
terraform state rm module.old_resource

# Taints resource for recreation
terraform taint module.template

# Shows what will change
terraform plan -destroy
```

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| API token invalid | Check format: `user@realm!token_name=secret` |
| Storage not found | Verify storage in Proxmox: `pvesh get /storage` |
| SSH connection denied | Ensure public key in `/root/.ssh/authorized_keys` |
| Image download fails | Check URL is accessible and checksum is correct |
| Cloud-init not applied | Verify vendor_data_file_id path in module |
| Permission denied | Check Proxmox role permissions for API token |

## Getting Help

1. **Check documentation**
   - `docs/README.md` - Overview
   - `docs/ARCHITECTURE.md` - Design
   - `docs/DEPLOYMENT.md` - Setup guide

2. **Run validation**
   - `bash scripts/validate.sh` - Check configuration

3. **Check Terraform logs**
   - `TF_LOG=DEBUG terraform plan` - Debug output

4. **Proxmox references**
   - [BPG Proxmox Provider](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
   - [Proxmox VE Docs](https://pve.proxmox.com/pve-docs/)
