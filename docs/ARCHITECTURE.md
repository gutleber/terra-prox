# Architecture Documentation

## Overview

This Terraform configuration implements infrastructure-as-code for Proxmox VE, providing a modular approach to managing VMs, LXC containers, and templates across multiple environments.

## Design Principles

### 1. Modularity
- **Separate Concerns**: Each module (template, VM, LXC) handles a specific resource type
- **Reusability**: Modules can be instantiated multiple times with different variables
- **Composability**: Modules can be combined in different ways for different use cases

### 2. Environment Separation
- **Configuration Isolation**: Each environment (dev, staging, prod) has separate tfvars
- **Independent State**: Each environment maintains its own Terraform state
- **Graduated Rollout**: Changes can be tested in dev before prod deployment

### 3. Security
- **Sensitive Variables**: Credentials marked as sensitive in variable definitions
- **Least Privilege**: Uses specific API token instead of root credentials
- **SSH Key Injection**: Cloud-init for secure access without passwords

## Resource Management with for_each

This architecture uses Terraform's `for_each` pattern for scalable resource management:

### Templates (for_each over map)
```hcl
module "template" {
  for_each = var.templates
  source = "./modules/template"
  vm_id = each.value.vm_id
  # ... other configuration from each.value
}
```
**Benefits:**
- Define multiple templates in tfvars
- Each template is a named map entry
- Easy to reference by template name

### VMs (for_each over list)
```hcl
module "vm" {
  for_each = { for vm in var.vm_configs : vm.name => vm }
  source = "./modules/vm"
  template_vm_id = module.template[each.value.template].vm_id
  # ... other configuration from each.value
}
```
**Benefits:**
- Multiple VMs with unique configurations
- Each VM references a specific template
- Can use different templates for different VMs
- Easy to add/remove VMs by updating tfvars

### LXC Containers (for_each over list)
```hcl
module "lxc" {
  for_each = { for container in var.lxc_configs : container.name => container }
  source = "./modules/lxc"
  # ... configuration from each.value
}
```
**Benefits:**
- Multiple containers with individual settings
- Per-container OS type and version
- Full customization per container

### Accessing Resources in for_each

**Templates:**
```hcl
module.template["ubuntu22"].vm_id
module.template["debian12"].template_id
```

**VMs:**
```hcl
module.vm["web-01"].ip_address
module.vm["db-01"].vm_id
```

**LXC:**
```hcl
module.lxc["monitor"].container_id
module.lxc["logging"].ip_address
```

### Outputs with for_each

All outputs iterate over the for_each blocks to provide comprehensive information:

```hcl
output "vms_created" {
  value = {
    for name, vm in module.vm :
    name => {
      vm_id    = vm.vm_id
      ip_address = vm.ip_address
    }
  }
}
```

### Configuration File Structure

**Templates Definition:**
```hcl
templates = {
  "ubuntu22" = {
    vm_id = 9000
    image_url = "..."
    # ... template-specific config
  }
  "debian12" = {
    vm_id = 9001
    image_url = "..."
    # ... template-specific config
  }
}
```

**VMs Definition:**
```hcl
vm_configs = [
  {
    name     = "web-01"
    template = "ubuntu22"    # References template key
    vm_id    = 100
    cores    = 2
    # ... VM-specific config
  },
  {
    name     = "db-01"
    template = "debian12"    # Different template
    vm_id    = 101
    cores    = 8
    # ... VM-specific config
  }
]
```

## Module Architecture

```
┌─────────────────────────────────────────┐
│         Root Configuration              │
│    (providers.tf, variables.tf)         │
└──────────────┬──────────────────────────┘
               │
       ┌───────┼───────┐
       │       │       │
       ▼       ▼       ▼
    ┌────────────────┐  ┌────────────┐  ┌──────────────┐
    │ Template Module│  │  VM Module │  │ LXC Module   │
    └────────────────┘  └────────────┘  └──────────────┘
       │                    │                │
       ▼                    ▼                ▼
    VM Image          VM from Template    Container
    Cloud-init        Cloud-init          Network
    Settings          Network             Storage
```

## Template Module (`modules/template`)

**Purpose**: Create a reusable VM template from cloud images

**Resources**:
- `proxmox_virtual_environment_download_file`: Download cloud image
- `proxmox_virtual_environment_file`: Store cloud-init configuration
- `proxmox_virtual_environment_vm`: Create template VM

**Lifecycle**:
1. Download image from URL with checksum verification
2. Create cloud-init vendor data file
3. Create VM with image, mark as template, don't start

**Outputs**:
- Template ID for cloning
- Image ID for reference
- Template reference string

## VM Module (`modules/vm`)

**Purpose**: Create and manage VMs by cloning from templates

**Resources**:
- `proxmox_virtual_environment_vm`: Clone from template
- `proxmox_virtual_environment_firewall_rules`: (Optional) Firewall rules

**Capabilities**:
- Clone from existing template (reference by ID)
- Override CPU, memory, disk configuration
- Apply cloud-init customization
- Configure network devices
- Add optional firewall rules

**Key Features**:
- Ignores cloud-init changes after creation (prevents recreation)
- Supports multiple network devices
- Flexible disk configuration
- Optional firewall integration

## LXC Module (`modules/lxc`)

**Purpose**: Create and manage LXC containers

**Resources**:
- `proxmox_virtual_environment_container`: Create container
- `proxmox_virtual_environment_firewall_rules`: (Optional) Firewall rules

**Capabilities**:
- Support for multiple OS types (Debian, Ubuntu, Alpine, etc.)
- Resource allocation (CPU cores, memory, disk)
- Unprivileged container mode (security)
- Network device configuration
- SSH key injection

**Key Features**:
- Lightweight compared to full VMs
- Faster startup times
- Lower resource requirements
- Unprivileged mode by default (more secure)

## Data Flow

### Template Creation
```
Cloud Image URL
      │
      ▼
┌─────────────────────┐
│ Download Image      │
│ (verify checksum)   │
└──────┬──────────────┘
       │
       ▼
┌──────────────────────┐
│ Create Cloud-init    │
│ Configuration        │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ Create Template VM   │
│ Attach image & conf  │
│ Mark as template     │
└──────┬───────────────┘
       │
       ▼
  Template Ready
```

### VM from Template
```
Template VM
     │
     ▼
┌──────────────────┐
│ Clone Template   │
│ (copy disks)     │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ Apply Custom     │
│ Configuration    │
│ (CPU, memory)    │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ Cloud-init       │
│ Customization    │
└──────┬───────────┘
       │
       ▼
   VM Ready
```

## Environment Architecture

```
┌─────────────────────────────────────────────┐
│          DEV Environment                    │
│  • Template creation testing                │
│  • Single template, no VMs/containers      │
│  • Lower resource allocation                │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│       STAGING Environment                   │
│  • Production-like setup                    │
│  • Template + example VM                    │
│  • Testing before production               │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│       PROD Environment                      │
│  • Full infrastructure                      │
│  • Templates, VMs, LXC containers          │
│  • Higher resource allocation               │
│  • Strict change management                 │
└─────────────────────────────────────────────┘
```

## Network Architecture

```
┌──────────────────────────────────────┐
│        Proxmox Node (pve)            │
│                                      │
│  ┌───────────────────────────────┐  │
│  │      Virtual Bridge (vmbr0)   │  │
│  │                               │  │
│  │  ┌──────────────────────────┐ │  │
│  │  │    Template VM           │ │  │
│  │  │  eth0: DHCP (vlan 1)     │ │  │
│  │  └──────────────────────────┘ │  │
│  │                               │  │
│  │  ┌──────────────────────────┐ │  │
│  │  │    VM Clone              │ │  │
│  │  │  eth0: DHCP (vlan 1)     │ │  │
│  │  └──────────────────────────┘ │  │
│  │                               │  │
│  │  ┌──────────────────────────┐ │  │
│  │  │    LXC Container         │ │  │
│  │  │  eth0: DHCP (vlan 1)     │ │  │
│  │  └──────────────────────────┘ │  │
│  │                               │  │
│  └───────────────────────────────┘  │
│                                      │
└──────────────────────────────────────┘
```

## State Management

### Local State (Development)
```
terraform/
├── .terraform/
├── terraform.tfstate           # Current state
├── terraform.tfstate.backup    # Previous state backup
└── .terraform.lock.hcl         # Provider lock file
```

### Remote State (Recommended for Teams)

Configure S3 backend:
```hcl
backend "s3" {
  bucket         = "terraform-state-bucket"
  key            = "proxmox/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-locks"
}
```

Benefits:
- Team collaboration
- State locking (prevent concurrent changes)
- Encryption at rest
- Audit trail
- Version control

## Scaling Considerations

### Horizontal Scaling
```hcl
# Create multiple VMs from same template
module "vm_web" {
  count = 3
  # ... web server configuration
}

module "vm_app" {
  count = 5
  # ... application server configuration
}
```

### Resource Limits
- VM IDs: Use offset strategy (template: 9000, vms: 9100+, lxc: 9200+)
- Storage: Plan disk allocation before deployment
- Network: Consider VLAN strategy for isolation

## Security Architecture

### Authentication
- API token-based (not passwords)
- SSH key injection (not cloud-init passwords)
- Unprivileged LXC containers by default

### Network Isolation
- VLAN separation per environment
- Firewall rules support per resource
- Cloud-init for host-level firewall (optional)

### Data Protection
- Sensitive variables marked in Terraform
- State file encryption (if using remote backend)
- SSH key for secure access

## Disaster Recovery

### Backup Strategy
1. Template backups (prevent_destroy lifecycle)
2. VM snapshots (manual or via scripts)
3. State file backups (automated via backend)
4. Configuration as code (git repository)

### Recovery Procedure
```bash
# 1. Restore from git
git checkout <previous-commit>

# 2. Refresh state
terraform refresh -var-file=environments/prod/terraform.tfvars

# 3. Recreate resources
terraform apply -var-file=environments/prod/terraform.tfvars
```

## Performance Considerations

- **Template Caching**: Images downloaded once, reused for clones
- **LXC vs VM**: Use LXC for lightweight workloads
- **Resource Allocation**: Balance between utilization and performance
- **Storage**: Use LVM for better performance than directory storage

## Maintenance

### Regular Tasks
1. Update cloud image checksums (monthly)
2. Update Terraform provider version (quarterly)
3. Test disaster recovery (quarterly)
4. Review and optimize resource allocation (quarterly)

### Monitoring Integration
- Terraform outputs provide resource IDs for monitoring setup
- Tags enable monitoring system integration
- SSH access enables agent installation for monitoring
