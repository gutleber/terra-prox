# Terraform Proxmox Infrastructure as Code

This repository contains a scalable Terraform configuration for deploying and managing VMs, LXC containers, and templates on Proxmox VE.

## Project Structure

```
terraform-vm-proxmox/
├── terraform/                   # Main Terraform configuration
│   ├── providers.tf            # Provider configuration
│   ├── variables.tf            # Global variables
│   ├── outputs.tf              # Output values
│   ├── main.tf                 # Root orchestration
│   ├── modules/
│   │   ├── template/           # VM template module
│   │   ├── vm/                 # VM cloning module
│   │   └── lxc/                # LXC container module
│   ├── environments/
│   │   ├── dev/                # Development environment
│   │   ├── dev-zfs/            # Development with ZFS RAID1
│   │   ├── staging/            # Staging environment
│   │   └── prod/               # Production environment
│   └── stacks/                 # Stack compositions (future)
├── docs/                       # Documentation
│   ├── ZFS_SETUP.md            # ZFS RAID1 configuration guide
├── scripts/                    # Utility scripts
└── .gitignore                  # Git ignore rules
```

## Requirements

- Terraform >= 1.5.0
- Proxmox VE >= 7.0
- BPG Proxmox Terraform Provider >= 0.53.1
- SSH access to Proxmox node
- API token with sufficient permissions

## Quick Start

### 1. Configure Credentials

Create a `.env` file (do not commit to git):

```bash
export TF_VAR_pve_api_url="https://pve.example.com/api2/json"
export TF_VAR_pve_token_id="terraform@pve!token_name"
export TF_VAR_pve_token_secret="YOUR_TOKEN_SECRET"
export TF_VAR_pve_user="terraform"
export TF_VAR_pve_ssh_key_private="~/.ssh/terraform_id_ed25519"
```

**For ZFS RAID1 setup**, use the provided example:

```bash
cp .env.zfs.example .env
# Edit .env with your Proxmox details
```

Source it before running Terraform:

```bash
source .env
```

### 2. Initialize Terraform

```bash
cd terraform
terraform init
```

### 3. Select Environment

Choose your environment (dev, staging, or prod):

```bash
# Development
terraform plan -var-file=environments/dev/terraform.tfvars

# Development with ZFS RAID1
terraform plan -var-file=environments/dev-zfs/terraform.tfvars

# Staging
terraform plan -var-file=environments/staging/terraform.tfvars

# Production
terraform plan -var-file=environments/prod/terraform.tfvars
```

Or use the Makefile for convenience:

```bash
make plan-dev      # Plan development
make plan-zfs      # Plan ZFS environment
make plan-staging  # Plan staging
make plan-prod     # Plan production
```

### 4. Plan and Apply

```bash
# Review changes
terraform plan -var-file=environments/dev/terraform.tfvars

# Apply changes
terraform apply -var-file=environments/dev/terraform.tfvars
```

## Multi-VM/LXC Configuration

This project uses a powerful configuration model that allows you to define multiple VMs and LXC containers with unique parameters in your environment's tfvars file.

### Configuration Structure

Each environment (dev, staging, prod) defines three main components:

#### 1. Templates - Reusable VM images

```hcl
templates = {
  "ubuntu22" = {
    vm_id                    = 9000
    image_url                = "https://cloud-images.ubuntu.com/releases/jammy/..."
    image_filename           = "ubuntu-22.04-server-cloudimg-amd64.img"
    image_checksum           = "actual_checksum_here"
    image_checksum_algorithm = "sha256"
    bios                     = "seabios"
    cores                    = 2
    memory                   = 2048
    disk_size                = 20
  }

  "debian12" = {
    # Similar structure for Debian
  }
}
```

#### 2. VMs - Multiple virtual machines with custom parameters

```hcl
vm_configs = [
  {
    name             = "web-server-01"
    template         = "ubuntu22"              # Reference template by key
    vm_id            = 100
    cores            = 2
    memory           = 2048
    disk_size        = 20
    autostart        = false
    enable_cloud_init = true
    cloud_init_user  = "ubuntu"

    network_devices = [{
      bridge  = "vmbr0"
      vlan_id = 1
    }]

    ip_configs = [{
      ipv4_address = "192.168.1.10/24"
      ipv4_gateway = "192.168.1.1"
    }]

    additional_disks = [{
      datastore_id = "local-lvm"
      interface    = "scsi1"
      size         = 100
      file_format  = "raw"
      cache        = "writeback"
      ssd          = true
    }]

    enable_firewall = true
    firewall_rules = [
      {
        action    = "ACCEPT"
        direction = "IN"
        protocol  = "tcp"
        port      = "80"
        comment   = "HTTP"
      }
    ]

    tags = ["web", "prod"]
  },

  # Add more VMs as needed
  {
    name = "database-01"
    # ... different configuration
  }
]
```

#### 3. LXC Containers - Lightweight containers

```hcl
lxc_configs = [
  {
    name           = "monitor"
    container_id   = 200
    os_type        = "debian"
    os_version     = "12"
    cores          = 2
    memory         = 1024
    disk_size      = 50
    autostart      = true
    unprivileged   = true

    network_devices = [{
      name    = "eth0"
      bridge  = "vmbr0"
      vlan_id = 1
    }]

    dns_servers     = ["8.8.8.8", "8.8.4.4"]
    ssh_public_keys = ["ssh-rsa AAAA..."]

    enable_firewall = true
    firewall_rules  = [...]

    tags = ["monitoring"]
  }
]
```

### Key Features

- **Multiple Templates**: Define different OS/version combinations in one environment
- **Per-Resource Customization**: Each VM/container has unique CPU, memory, disk, network, and firewall rules
- **Template References**: VMs specify which template to use with simple string reference
- **Advanced Networking**: Support for static IPs, multiple NICs, VLANs, IPv6
- **Additional Storage**: Add extra disks to any VM with full control
- **Firewall Rules**: Per-resource firewall rules with ports, protocols, and source/destination
- **Tags**: Organizational tags for resource management and filtering

### Example Environments

- **dev**: 2 templates, 2 VMs, 1 LXC - ideal for testing (traditional storage)
- **dev-zfs**: Same as dev but configured for ZFS RAID1 storage (Proxmox 9.1.1+)
- **staging**: Production-like setup with web, app, and database servers + monitoring
- **prod**: Full production deployment with load balancers, redundancy, monitoring, logging, and backups

See each environment's tfvars file for detailed examples.

**Note**: If using Proxmox VE 9.1.1 with ZFS RAID1, use the `dev-zfs` environment as a template or reference for your configuration.

## Modules

### Template Module (`modules/template`)

Creates a VM template from a cloud image.

**Features:**
- Downloads cloud images (Ubuntu, Debian, etc.)
- Configures cloud-init for customization
- Creates reusable VM template

**Usage:**
```hcl
module "template" {
  source = "./modules/template"

  node_name = "pve"
  vm_id = 9000
  vm_name = "debian-12-template"
  image_url = "https://..."
  # ... more variables
}
```

### VM Module (`modules/vm`)

Clones VMs from a template.

**Features:**
- Clone from existing template
- Configure CPU, memory, disks
- Cloud-init customization
- Firewall rules

**Usage:**
```hcl
module "vm" {
  source = "./modules/vm"

  node_name = "pve"
  vm_id = 9100
  vm_name = "web-server-01"
  template_vm_id = 9000
  # ... more variables
}
```

### LXC Module (`modules/lxc`)

Creates and manages LXC containers.

**Features:**
- Support for Debian, Ubuntu, Alpine, etc.
- Resource allocation (CPU, memory, disk)
- Network configuration
- SSH key injection

**Usage:**
```hcl
module "lxc" {
  source = "./modules/lxc"

  node_name = "pve"
  container_id = 9200
  container_name = "app-container-01"
  os_type = "debian"
  os_version = "12"
  # ... more variables
}
```

## Environments

### Development (`environments/dev`)
- Single template, no VMs or containers
- Suitable for testing template creation
- Lower resource allocation

### Staging (`environments/staging`)
- Template + sample VM
- Testing production-like setup
- Standard resource allocation

### Production (`environments/prod`)
- Full setup: template, VMs, and LXC containers
- Higher resource allocation
- Production VLAN

## Common Operations

### Create a VM Template

```bash
cd terraform
terraform apply -var-file=environments/dev/terraform.tfvars -target=module.template
```

### Create VMs from Template

```bash
# Enable VM creation in tfvars, then:
terraform apply -var-file=environments/staging/terraform.tfvars -target=module.vm
```

### Create LXC Containers

```bash
# Enable LXC creation in tfvars, then:
terraform apply -var-file=environments/prod/terraform.tfvars -target=module.lxc
```

### Destroy Resources

```bash
# Destroy specific module
terraform destroy -var-file=environments/dev/terraform.tfvars -target=module.vm

# Destroy entire environment
terraform destroy -var-file=environments/dev/terraform.tfvars
```

## Image Configuration

Before creating templates, ensure you have the correct checksums for cloud images:

```bash
# Ubuntu
wget https://cloud-images.ubuntu.com/releases/jammy/release-latest/SHA256SUMS
grep ubuntu-22.04-server-cloudimg-amd64.img SHA256SUMS

# Debian
wget https://cloud.debian.org/images/cloud/bookworm/latest/SHA512SUMS
grep debian-12-generic-amd64.qcow2 SHA512SUMS
```

Update the checksum in your `environments/*/terraform.tfvars` files.

## Networking

### Default Configuration
- Bridge: `vmbr0`
- VLAN: 1 (dev), 2 (staging), 10 (prod)
- DNS: 8.8.8.8, 8.8.4.4

### Custom Network Setup

Modify `network_devices` in the module configuration:

```hcl
network_devices = [
  {
    bridge  = "vmbr1"
    vlan_id = 100
  }
]
```

## Troubleshooting

### Provider Authentication Error

Ensure your API token has correct format:
```
user@realm!token_name=token_secret
```

Check permissions on Proxmox:
- Datastore.AllocateSpace
- Datastore.Audit
- VM.Allocate
- VM.Clone
- VM.Config.*
- VM.Console

### Template Creation Fails

- Verify image checksum matches exactly
- Ensure datastore has sufficient space
- Check SSH key has write permissions

### Cloud-init Not Applied

- Verify `vendor_data_file_id` path is correct
- Check container type supports cloud-init
- Review Proxmox task logs

## ZFS RAID1 Configuration (Proxmox VE 9.1.1+)

This project supports ZFS storage backends. If you're using Proxmox VE 9.1.1 with ZFS RAID1:

### Quick Start for ZFS

1. **Use the ZFS environment example**:
   ```bash
   cp .env.zfs.example .env
   # Edit .env with your values
   source .env
   ```

2. **Deploy using ZFS configuration**:
   ```bash
   make plan-zfs
   make apply-zfs
   ```

3. **Update storage variables in your tfvars**:
   ```hcl
   storage_local   = "local-zfs"    # For ISOs and backups
   storage_vm_disk = "local-zfs"    # For VM disks
   ```

### Key Changes

- **Variable renamed**: `storage_lvm` → `storage_vm_disk` (more generic, supports ZFS, LVM, Ceph, etc.)
- **ZFS example**: `terraform/environments/dev-zfs/` - Ready-to-use ZFS configuration
- **Full guide**: See `docs/ZFS_SETUP.md` for comprehensive ZFS configuration details

### Storage Type Support

| Storage Type | storage_local | storage_vm_disk | Example |
|---|---|---|---|
| **Directory** | `local` | `local-lvm` | Traditional setup |
| **ZFS** | `local-zfs` | `local-zfs` | RAID1/RAID10 |
| **Ceph** | `ceph-iso` | `ceph-vm` | Distributed storage |
| **Mixed** | `local` | `local-zfs` | ISOs on dir, VMs on ZFS |

For detailed ZFS setup instructions, permissions, and troubleshooting, see `docs/ZFS_SETUP.md`.

## Best Practices

1. **Use separate tfvars for each environment**
2. **Manage sensitive data with environment variables or secret managers**
3. **Always run `terraform plan` before `apply`**
4. **Tag resources for cost tracking and organization**
5. **Use remote state backend for team collaboration**
6. **Implement CI/CD for automated deployments**

## Remote State Configuration

To enable remote state (recommended for teams):

```hcl
# terraform/providers.tf
terraform {
  backend "s3" {
    bucket         = "terraform-state"
    key            = "proxmox/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

## Contributing

1. Test changes in dev environment first
2. Run `terraform validate` and `terraform fmt`
3. Document any new variables or modules
4. Keep environments synchronized

## Support

For issues with the Proxmox provider, see:
- [BPG Proxmox Provider Documentation](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)

## License

[Specify your license here]
