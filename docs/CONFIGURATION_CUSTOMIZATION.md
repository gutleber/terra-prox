# Configuration Customization Guide

This guide explains all the hardcoded and parameterizable values in the Terraform configuration and how to customize them for your environment.

## Overview

All configuration values in this project are customizable at multiple levels:
1. **Global variables** (root-level `variables.tf`)
2. **Environment variables** (`.env` file)
3. **Environment-specific tfvars** (`environments/*/terraform.tfvars`)
4. **Per-resource customization** (in tfvars files)

## Global Configuration Variables

These variables are defined in `terraform/variables.tf` and can be overridden via environment variables or tfvars files.

### Storage Configuration

#### `storage_local`
- **Purpose**: Storage datastore for ISOs, backups, and snippets
- **Default**: `local` (directory-based storage)
- **Customization**:
  ```hcl
  # In tfvars or .env
  storage_local = "local-zfs"   # For ZFS
  storage_local = "local"       # For directory storage
  storage_local = "pbs"         # For Proxmox Backup Server
  ```
- **Common Values**:
  - `local` - Directory storage (standard)
  - `local-zfs` - ZFS pool (recommended for Proxmox 9.1.1+)
  - `pbs` - Proxmox Backup Server
  - `nfs-share` - NFS storage
  - `ceph-iso` - Ceph storage

#### `storage_vm_disk`
- **Purpose**: Storage datastore for VM disks
- **Default**: `local-lvm` (LVM storage)
- **Customization**:
  ```hcl
  storage_vm_disk = "local-lvm"    # LVM (traditional)
  storage_vm_disk = "local-zfs"    # ZFS (modern)
  storage_vm_disk = "ceph-vm"      # Ceph (distributed)
  ```
- **Common Values**:
  - `local-lvm` - LVM storage (standard)
  - `local-zfs` - ZFS pool (high performance)
  - `ceph-vm` - Ceph distributed storage
  - `ceph-pool` - Another Ceph pool name

### Network Configuration

#### `bridge_interface`
- **Purpose**: Primary network bridge for VMs and containers
- **Default**: `vmbr0`
- **Customization**:
  ```hcl
  bridge_interface = "vmbr0"    # Standard bridge
  bridge_interface = "vmbr1"    # Alternative bridge
  bridge_interface = "vmbr100"  # Custom bridge for specific VLAN
  ```
- **Note**: Multiple bridges can be specified per VM in `network_devices` list

#### `vlan_id`
- **Purpose**: Default VLAN ID for network isolation
- **Default**: `1` (no VLAN)
- **Customization**:
  ```hcl
  vlan_id = 1       # No VLAN (native)
  vlan_id = 10      # Production VLAN
  vlan_id = 100     # Custom VLAN
  ```
- **Note**: Can be overridden per VM in `network_devices` list

### Disk & Storage Performance Configuration

These variables control disk performance and behavior across all templates.

#### `disk_cache`
- **Purpose**: Disk cache mode (affects performance and data safety)
- **Default**: `writeback` (fast, good balance)
- **Options**:
  - `writeback` - **Default**. Fast writes, risk of data loss on crash
  - `writethrough` - Safe writes, slower performance
  - `unsafe` - Fastest, highest risk
- **Customization**:
  ```hcl
  # For development/testing (prioritize speed)
  disk_cache = "unsafe"

  # For production (prioritize safety)
  disk_cache = "writethrough"

  # For balanced setup
  disk_cache = "writeback"
  ```
- **Recommendation**: Use `writeback` for most setups, `writethrough` for production databases

#### `disk_discard`
- **Purpose**: TRIM/DISCARD support (enables SSD space reclamation)
- **Default**: `on` (enabled)
- **Options**:
  - `on` - **Default**. Enable TRIM support (recommended for SSDs)
  - `off` - Disable TRIM
  - `ignore` - Attempt TRIM but ignore errors
- **Customization**:
  ```hcl
  # For SSD storage (recommended)
  disk_discard = "on"

  # For legacy systems
  disk_discard = "off"

  # For problematic SSD controllers
  disk_discard = "ignore"
  ```
- **Recommendation**: Keep enabled (`on`) for SSDs, disable for HDD/NAS

#### `disk_format`
- **Purpose**: Disk image format (affects performance, flexibility, portability)
- **Default**: `raw` (best performance)
- **Options**:
  - `raw` - **Default**. Best performance, no flexibility
  - `qcow2` - Good balance of performance and flexibility
  - `vmdk` - VMware compatibility
- **Customization**:
  ```hcl
  # For maximum performance (recommended)
  disk_format = "raw"

  # For dynamic disk sizing
  disk_format = "qcow2"

  # For VMware migration
  disk_format = "vmdk"
  ```
- **Recommendation**: Use `raw` for performance, `qcow2` if you need dynamic sizing

#### `disk_ssd`
- **Purpose**: Enable SSD-specific optimizations
- **Default**: `true` (enabled)
- **Customization**:
  ```hcl
  # For SSD storage
  disk_ssd = true

  # For HDD/traditional storage
  disk_ssd = false
  ```
- **Recommendation**: Set to `true` for SSD/fast storage, `false` for HDD/NAS

### Template Defaults

#### `default_bios`
- **Purpose**: Default BIOS type for new templates
- **Default**: `seabios`
- **Options**:
  - `seabios` - **Default**. Compatibility mode (x86 traditional)
  - `ovmf` - UEFI mode (modern, required for Secure Boot)
- **Customization**:
  ```hcl
  # For modern VMs (recommended)
  default_bios = "ovmf"

  # For older OS compatibility
  default_bios = "seabios"
  ```
- **Note**: Can be overridden per template

#### `default_machine_type`
- **Purpose**: Default machine type for new templates
- **Default**: `q35`
- **Options**:
  - `q35` - **Default**. Modern machine type (2009+)
  - `i440fx` - Legacy machine type
- **Customization**:
  ```hcl
  # For modern systems (recommended)
  default_machine_type = "q35"

  # For legacy compatibility
  default_machine_type = "i440fx"
  ```
- **Note**: Can be overridden per template

## Environment-Specific Customization

### Development Environment (`environments/dev/terraform.tfvars`)

All variables with explanatory comments:

```hcl
node              = "pve"                      # Your node name
datacenter        = "local"                    # Datacenter ID
storage_local     = "local"                    # ISO storage
storage_vm_disk   = "local-lvm"                # VM disk storage
bridge_interface  = "vmbr0"                    # Network bridge
vlan_id           = 1                          # VLAN ID

# Performance settings
disk_cache        = "writeback"                # Disk cache mode
disk_discard      = "on"                       # Enable TRIM
disk_format       = "raw"                      # Disk format
disk_ssd          = true                       # SSD optimization
```

### Template-Level Customization

Templates can override global defaults:

```hcl
templates = {
  "ubuntu22" = {
    # ... other settings ...
    bios         = "seabios"      # Override default_bios
    machine_type = "q35"          # Override default_machine_type
  }
  "ubuntu-uefi" = {
    bios         = "ovmf"         # UEFI-based Ubuntu
    machine_type = "q35"
  }
}
```

### VM-Level Customization

VMs can customize network and storage per-resource:

```hcl
vm_configs = [
  {
    name   = "web-01"
    template = "ubuntu22"

    # Network customization per VM
    network_devices = [
      {
        bridge  = "vmbr0"          # Override global bridge_interface
        vlan_id = 100              # Override global vlan_id
      },
      {
        bridge  = "vmbr1"          # Additional network interface
        vlan_id = 200
      }
    ]

    # Additional disks with custom storage configuration
    additional_disks = [
      {
        datastore_id = "local-zfs"              # Override storage_vm_disk
        interface    = "scsi1"
        size         = 200
        file_format  = "raw"                    # Override disk_format
        cache        = "writeback"              # Override disk_cache
        ssd          = true                     # Override disk_ssd
        discard      = "on"                     # Override disk_discard
      }
    ]
  }
]
```

## Complete Customization Examples

### Example 1: ZFS RAID1 Setup (Proxmox 9.1.1)

```hcl
# Use same variables everywhere for ZFS
storage_local   = "local-zfs"
storage_vm_disk = "local-zfs"

# Optimize for ZFS performance
disk_cache  = "writeback"
disk_format = "raw"
disk_ssd    = true
disk_discard = "on"
```

### Example 2: Ceph Distributed Storage

```hcl
storage_local   = "ceph-iso"        # ISOs on Ceph
storage_vm_disk = "ceph-vm"         # VMs on Ceph

# Ceph is network storage, adjust cache
disk_cache = "writeback"            # Balance performance and latency

# Additional disks can use different pools
additional_disks = [
  {
    datastore_id = "ceph-ssd"       # Fast pool
    size = 100
  },
  {
    datastore_id = "ceph-spindle"   # Archive pool
    size = 1000
  }
]
```

### Example 3: Mixed Storage (Directory + ZFS)

```hcl
storage_local   = "local"           # ISOs on directory (cheap)
storage_vm_disk = "local-zfs"       # VMs on ZFS (performance)

# VM-specific customization for different tiers
vm_configs = [
  {
    name = "critical-db"
    additional_disks = [
      {
        datastore_id = "local-zfs"  # Use ZFS for critical data
        cache = "writethrough"       # Safer writes
        ssd = true
      }
    ]
  },
  {
    name = "archive-box"
    additional_disks = [
      {
        datastore_id = "local"      # Use cheap directory storage
        size = 5000                 # Large capacity
        ssd = false                 # HDD storage
      }
    ]
  }
]
```

### Example 4: High-Performance Production Setup

```hcl
storage_local   = "local-zfs"
storage_vm_disk = "local-zfs"

# Optimize for maximum performance
disk_cache  = "unsafe"              # Fastest writes (with battery backup)
disk_format = "raw"                 # Best performance
disk_ssd    = true                  # SSD optimizations
disk_discard = "on"                 # TRIM enabled

# Use OVMF for modern VMs
default_bios          = "ovmf"
default_machine_type  = "q35"
```

## Network Device Customization

Each VM can have multiple network interfaces with different configurations:

```hcl
vm_configs = [
  {
    name = "multi-net-vm"

    network_devices = [
      {
        bridge  = "vmbr0"
        vlan_id = 10        # Management network
      },
      {
        bridge  = "vmbr1"
        vlan_id = 20        # Data network
      },
      {
        bridge  = "vmbr2"
        vlan_id = 30        # Storage network
      }
    ]
  }
]
```

## Storage Interface Selection

Additional disks can use different interfaces based on your needs:

```hcl
additional_disks = [
  {
    interface = "scsi0"    # SCSI - high performance (main disk usually scsi0)
  },
  {
    interface = "scsi1"    # SCSI - additional data disk
  },
  {
    interface = "virtio0"  # VirtIO - para-virtualized (good performance)
  },
  {
    interface = "ide0"     # IDE - legacy compatibility
  },
  {
    interface = "sata0"    # SATA - compatibility
  }
]
```

**Recommendations**:
- `scsi*` - Best for performance, recommended for most VMs
- `virtio*` - Good alternative if SCSI has issues
- `ide*`/`sata*` - Use only for legacy OS compatibility

## Disk Defaults with Terraform Locals

Each environment uses a `locals` block that creates a reusable disk configuration template. This eliminates hardcoded values in individual additional_disks entries while leveraging the root-level variables for consistency.

### How Locals Work

The `locals` block in each tfvars file creates a disk configuration template that inherits all values from root-level variables:

```hcl
# In any environments/*/terraform.tfvars
locals {
  default_disk_config = {
    datastore_id = var.storage_vm_disk  # Inherits from root variable
    file_format  = var.disk_format      # Inherits from root variable
    cache        = var.disk_cache       # Inherits from root variable
    ssd          = var.disk_ssd         # Inherits from root variable
    discard      = var.disk_discard     # Inherits from root variable
  }
}
```

Then use `merge()` in additional_disks to combine defaults with per-disk specifications:

```hcl
additional_disks = [
  merge(local.default_disk_config, {
    interface = "scsi1"
    size      = 200
  })
]
```

This creates a disk configuration that inherits all defaults from the locals block and only specifies what's unique to this disk.

### How to Customize Per-Environment

Edit the root-level disk variables in each environment's tfvars file:

```hcl
# environments/dev/terraform.tfvars
disk_cache   = "writeback"    # For development
disk_format  = "raw"
disk_ssd     = true
disk_discard = "on"

# environments/prod/terraform.tfvars
disk_cache   = "writeback"    # For production
disk_format  = "raw"
disk_ssd     = true
disk_discard = "on"
```

All VMs in that environment will automatically inherit the same defaults via `local.default_disk_config`.

### Example 1: Using Default Configuration

All disks in a VM inherit the environment's defaults:

```hcl
additional_disks = [
  merge(local.default_disk_config, {
    interface = "scsi1"
    size      = 200
  })
]
# Result: Uses values from disk_cache, disk_format, disk_ssd, disk_discard variables
```

### Example 2: Per-Disk Overrides

Override specific settings for critical resources:

```hcl
# Database disk with safety override
additional_disks = [
  merge(local.default_disk_config, {
    interface = "scsi1"
    size      = 1000
    cache     = "writethrough"     # Override: extra safety for DB
  })
]
# Result: All defaults + writethrough cache override
```

### Example 3: Multiple Disks with Different Overrides

```hcl
additional_disks = [
  # Fast cache disk
  merge(local.default_disk_config, {
    interface = "scsi1"
    size      = 500
    cache     = "unsafe"           # Override: maximum speed
  }),
  # Safe data disk
  merge(local.default_disk_config, {
    interface = "scsi2"
    size      = 2000
    cache     = "writethrough"      # Override: maximum safety
  })
]
```

### Adding Locals to Your Environment

If you're adding a new environment, create a locals block:

```hcl
# environments/custom/terraform.tfvars

disk_cache   = "writeback"    # Set environment-specific values
disk_format  = "raw"
disk_ssd     = true
disk_discard = "on"

locals {
  default_disk_config = {
    datastore_id = var.storage_vm_disk
    file_format  = var.disk_format
    cache        = var.disk_cache
    ssd          = var.disk_ssd
    discard      = var.disk_discard
  }
}

# Then use in VMs:
vm_configs = [
  {
    name = "vm-example"
    additional_disks = [
      merge(local.default_disk_config, {
        interface = "scsi1"
        size      = 200
      })
    ]
  }
]
```

### Benefits of This Approach

1. **Simplicity**: All environments share the same locals pattern
2. **Consistency**: All disks in an environment share the same baseline
3. **Easy Overrides**: Use `merge()` to customize individual disks
4. **Centralized Control**: Change one variable to update all disks in an environment
5. **DRY (Don't Repeat Yourself)**: No hardcoded values in additional_disks
6. **Flexible**: Customize per-environment via root-level variables

## How to Apply Custom Configuration

### Method 1: Edit tfvars File

Edit `environments/prod/terraform.tfvars` directly:

```hcl
storage_vm_disk = "local-zfs"
disk_cache = "writethrough"
disk_format = "raw"
```

Then apply:

```bash
terraform apply -var-file=environments/prod/terraform.tfvars
```

### Method 2: Override via Environment Variables

```bash
export TF_VAR_storage_vm_disk="local-zfs"
export TF_VAR_disk_cache="writethrough"
export TF_VAR_disk_format="raw"

terraform apply -var-file=environments/prod/terraform.tfvars
```

### Method 3: Command-Line Override

```bash
terraform apply \
  -var-file=environments/prod/terraform.tfvars \
  -var="storage_vm_disk=local-zfs" \
  -var="disk_cache=writethrough"
```

## Best Practices

1. **Use environment-specific values**: Different settings for dev/staging/prod
2. **Document your choices**: Add comments explaining why you chose specific values
3. **Test before production**: Always test configuration changes in dev first
4. **Monitor performance**: Check VM/host performance after changes
5. **Keep backups**: Backup VM configurations before making changes
6. **Use consistent names**: Maintain naming conventions across environments

## Troubleshooting

### Issue: "Datastore not found"
- **Cause**: Specified datastore doesn't exist in Proxmox
- **Solution**: Verify datastore name in Proxmox Web UI (Datacenter → Storage)

### Issue: "TRIM not supported"
- **Cause**: Storage backend or SSD doesn't support DISCARD
- **Solution**: Set `disk_discard = "off"` or `disk_discard = "ignore"`

### Issue: Poor disk performance
- **Cause**: Wrong cache settings or disk format
- **Solutions**:
  - Try `disk_cache = "writethrough"` for safety
  - Ensure `disk_ssd = true` for SSD storage
  - Use `disk_format = "raw"` for best performance

### Issue: VM takes long time to create
- **Cause**: Slow storage or inefficient format
- **Solutions**:
  - Use `disk_format = "raw"` instead of `qcow2`
  - Check if storage datastore is under heavy load
  - Verify network connectivity (for remote storage)

## References

- [Proxmox Storage Documentation](https://pve.proxmox.com/wiki/Storage)
- [Terraform Proxmox Provider](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
- [ZFS Configuration Guide](docs/ZFS_SETUP.md)
