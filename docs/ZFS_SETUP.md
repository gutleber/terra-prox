# ZFS RAID1 Configuration Guide for Proxmox VE 9.1.1

This guide explains how to configure Terraform for Proxmox VE 9.1.1 with ZFS RAID1 storage.

## Overview

Proxmox VE supports multiple storage backends:
- **Local Dir** - File-based storage (`local`)
- **LVM** - Logical Volume Manager (`local-lvm`)
- **ZFS** - ZFS pool storage (`local-zfs`)
- **Ceph** - Distributed storage (`ceph-pool`, etc.)

This guide focuses on **ZFS RAID1** setup, which is a robust and efficient storage solution.

## Storage Variable Changes

### What Changed

Previous configuration used two separate storage variables:
- `storage_local` - for ISOs and backups (default: `local`)
- `storage_lvm` - for VM disks (default: `local-lvm`)

**New configuration (v2):**
- `storage_local` - for ISOs and backups (default: `local`)
- `storage_vm_disk` - for VM disks (default: `local-lvm`)

**Why?** The old name `storage_lvm` was specific to LVM. The new name `storage_vm_disk` is more generic and works with any storage type (LVM, ZFS, Ceph, etc.).

### Backward Compatibility

If you have existing `.tfvars` files using `storage_lvm`, you must update them to `storage_vm_disk`:

```bash
# Old format (no longer supported)
storage_local = "local"
storage_lvm   = "local-lvm"

# New format
storage_local = "local"
storage_vm_disk = "local-lvm"
```

## ZFS RAID1 Configuration

### Step 1: Verify Your ZFS Pool

First, verify that your ZFS pool is configured in Proxmox:

```bash
# SSH to Proxmox node
ssh root@pve.example.com

# List ZFS pools
zpool list

# List ZFS datasets
zfs list

# Example output:
# NAME              SIZE  ALLOC   FREE  CAP  DEDUP  HEALTH  ALTROOT
# local-zfs        10.9T  5.1T   5.8T  47%  1.00x  ONLINE  -
```

### Step 2: Configure Environment Variables

Copy the provided ZFS example file:

```bash
cp .env.zfs.example .env
```

Edit `.env` and update these values:

```bash
# Your Proxmox API endpoint
export TF_VAR_pve_api_url="https://YOUR_HOST:8006/api2/json"

# Your API token (create via Proxmox → Datacenter → Permissions → API Tokens)
export TF_VAR_pve_token_id="terraform@pve!terraform-token"
export TF_VAR_pve_token_secret="YOUR_TOKEN_SECRET"

# Your node name
export TF_VAR_node="pve"

# ZFS pool name (usually "local-zfs")
export TF_VAR_storage_local="local-zfs"
export TF_VAR_storage_vm_disk="local-zfs"
```

Source the environment file:

```bash
source .env
```

### Step 3: Use the ZFS Environment Configuration

A pre-configured ZFS example is provided at `terraform/environments/dev-zfs/terraform.tfvars`:

```hcl
storage_local   = "local-zfs"
storage_vm_disk = "local-zfs"
```

### Step 4: Initialize and Deploy

```bash
# Initialize Terraform
cd terraform
terraform init

# Plan the ZFS environment
make plan-zfs

# Or manually:
terraform plan -var-file=environments/dev-zfs/terraform.tfvars

# Apply the configuration
make apply-zfs

# Or manually:
terraform apply -var-file=environments/dev-zfs/terraform.tfvars
```

## Configuration Examples

### Example 1: ZFS for Both ISOs and VM Disks

Both ISOs and VM disks stored on the same ZFS pool:

```hcl
storage_local   = "local-zfs"    # ISOs, backups on ZFS
storage_vm_disk = "local-zfs"    # VM disks on ZFS
```

### Example 2: Mixed Storage (ZFS + Directory)

ISOs on directory storage, VM disks on ZFS:

```hcl
storage_local   = "local"        # ISOs on directory
storage_vm_disk = "local-zfs"    # VM disks on ZFS
```

### Example 3: Multiple ZFS Pools

If you have multiple ZFS pools:

```hcl
storage_local   = "local-zfs-iso"    # One pool for ISOs
storage_vm_disk = "local-zfs-vm"     # Another pool for VM disks
```

## Storage Considerations

### ZFS Advantages

✓ **Data Integrity**: Built-in checksums and self-healing
✓ **Snapshots**: Fast, space-efficient snapshots
✓ **Compression**: Native compression (often 2-3x space savings)
✓ **Deduplication**: Optional deduplication support
✓ **RAID**: Native RAID 1/10/6/Z support

### ZFS Recommendations

1. **Use ZFS Compression**: Enable `lz4` compression for better performance
   ```bash
   zfs set compression=lz4 local-zfs
   ```

2. **Monitor Pool Health**: Check pool status regularly
   ```bash
   zpool status -x  # Show only unhealthy pools
   ```

3. **Reserve Space**: Leave 10-20% of pool free for performance
   ```bash
   zfs set reservation=1T local-zfs  # Reserve 1TB
   ```

4. **Regular Snapshots**: For VM templates and backups
   ```bash
   zfs snapshot local-zfs@weekly-backup
   ```

5. **Monitor ZFS Disk Usage**:
   ```bash
   zfs list -r local-zfs
   ```

## Troubleshooting

### Issue: Datastore "local-zfs" not found

**Cause**: ZFS pool name is different or not registered in Proxmox

**Solution**:
1. Verify pool exists: `zpool list`
2. Check Proxmox storage: Web UI → Datacenter → Storage
3. Update variable to match pool name

### Issue: Permission denied when creating VMs

**Cause**: Terraform user lacks permissions on ZFS pool

**Solution**:
```bash
# On Proxmox node, grant permissions to terraform user
pveum acl modify /storage/local-zfs -user terraform@pve -role PVEVMUser
```

### Issue: Out of disk space

**Cause**: ZFS pool is full

**Solution**:
1. Check pool usage: `zfs list`
2. Check for snapshots: `zfs list -t snapshot`
3. Delete old snapshots: `zfs destroy local-zfs@old-snapshot`
4. Monitor compression: `zfs get compression local-zfs`

### Issue: Slow VM performance

**Cause**: ZFS tuning needed

**Solution**:
1. Enable compression: `zfs set compression=lz4 local-zfs`
2. Adjust recordsize: `zfs set recordsize=64k local-zfs` (for VM workloads)
3. Monitor I/O: `zpool iostat 1`

## Makefile Targets

### ZFS-Specific Targets

```bash
# Plan ZFS environment
make plan-zfs

# Apply ZFS environment
make apply-zfs

# Destroy ZFS environment
make destroy-zfs
```

### Example Workflow

```bash
# 1. Source environment variables
source .env

# 2. Initialize Terraform
make init

# 3. Plan the deployment
make plan-zfs

# 4. Review the plan and apply
make apply-zfs

# 5. Verify deployment
terraform show

# 6. If needed, destroy
make destroy-zfs
```

## Variable Reference

### Root Variables (terraform/variables.tf)

| Variable | Description | Default | For ZFS |
|----------|-------------|---------|---------|
| `storage_local` | Storage for ISOs, backups | `local` | `local-zfs` |
| `storage_vm_disk` | Storage for VM disks | `local-lvm` | `local-zfs` |
| `node` | Proxmox node name | required | required |
| `bridge_interface` | Network bridge | `vmbr0` | `vmbr0` |

### Module Variables (modules/template/variables.tf)

Both template and vm modules accept:
- `storage_local` - overrides root variable
- `storage_vm_disk` - overrides root variable

### Example Override in tfvars

```hcl
# Override storage for specific templates
templates = {
  "ubuntu22" = {
    # ... other settings ...
    # Template will use root-level storage_vm_disk
  }
  "debian12" = {
    # ... other settings ...
    # Can override in per-VM configuration
  }
}

vm_configs = [
  {
    name = "web-01"
    # ... other settings ...
    # additional_disks can specify different storage
    additional_disks = [
      {
        datastore_id = "local-zfs"  # Can override here
        # ... other settings ...
      }
    ]
  }
]
```

## Performance Tuning

### For Development/Testing

```bash
# Disable compression if performance is preferred over space
zfs set compression=off local-zfs
```

### For Production

```bash
# Enable compression for space savings
zfs set compression=lz4 local-zfs

# Set dedup if you have duplicate data
# WARNING: Requires significant RAM
# zfs set dedup=on local-zfs

# Reserve space for optimal performance (10-20% of pool)
zfs set reservation=2T local-zfs
```

### Monitor Performance

```bash
# Real-time I/O stats
zpool iostat 1

# Check compression ratio
zfs get compressratio local-zfs

# Monitor dedup stats (if enabled)
zfs get dedupratio local-zfs
```

## Migration from LVM to ZFS

If migrating from `local-lvm` to `local-zfs`:

1. **Create ZFS pool first** (done in Proxmox)
2. **Update tfvars files**:
   ```hcl
   # Change from:
   storage_vm_disk = "local-lvm"

   # To:
   storage_vm_disk = "local-zfs"
   ```

3. **Existing VMs**: Manually migrate or leave on LVM, new VMs go to ZFS
4. **Gradually phase out LVM**: Delete LVM VMs as they're replaced with ZFS versions

## References

- [Proxmox ZFS Documentation](https://pve.proxmox.com/wiki/ZFS_on_Linux)
- [ZFS Documentation](https://openzfs.github.io/openzfs-docs/)
- [Terraform Proxmox Provider](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)

## Support

For issues specific to:
- **Terraform configuration**: Check `docs/DEPLOYMENT.md`
- **Proxmox permissions**: Check `docs/PROXMOX_SETUP_SUMMARY.md`
- **ZFS administration**: Consult Proxmox and ZFS documentation
