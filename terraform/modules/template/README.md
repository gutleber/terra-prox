# Template Module

Creates a reusable VM template from cloud images for use with Proxmox VE.

## Purpose

This module automates the creation of VM templates from cloud images (Ubuntu, Debian, etc.). The resulting template can be cloned to create new VMs quickly.

## Features

- Downloads cloud images with checksum verification
- Creates cloud-init configuration for customization
- Configures VM with specified resources
- Marks VM as template (non-bootable)
- Supports both SEABIOS and UEFI (OVMF) firmware

## Usage

```hcl
module "template" {
  source = "./modules/template"

  node_name                 = "pve"
  vm_id                     = 9000
  vm_name                   = "debian-12-template"
  image_url                 = "https://..."
  image_filename            = "debian-12-generic-amd64.img"
  image_checksum            = "abc123..."
  image_checksum_algorithm  = "sha256"

  cores                     = 2
  memory                    = 2048
  disk_size                 = 20
}
```

## Resources

### proxmox_virtual_environment_download_file
- Downloads cloud image from URL
- Verifies checksum
- Stores in local datastore
- Lifecycle: prevent_destroy

### proxmox_virtual_environment_file
- Creates cloud-init vendor data configuration
- Stores as snippets file on Proxmox
- Lifecycle: prevent_destroy

### proxmox_virtual_environment_vm
- Creates VM from downloaded image
- Configures CPU, memory, disk
- Sets up cloud-init
- Marks as template (not started)

## Variables

### Required

- `node_name` (string) - Proxmox node name
- `vm_id` (number) - VM ID for template
- `vm_name` (string) - VM template name
- `image_url` (string) - URL to cloud image
- `image_filename` (string) - Filename for downloaded image
- `image_checksum` (string) - Checksum of image
- `image_checksum_algorithm` (string) - Algorithm (sha256, sha512)

### Optional with Defaults

- `bios` (string) - BIOS type, default: "seabios"
- `machine_type` (string) - Machine type, default: "q35"
- `cores` (number) - CPU cores, default: 2
- `memory` (number) - Memory in MB, default: 2048
- `disk_size` (number) - Disk size in GB, default: 20
- `storage_local` (string) - Local storage, default: "local"
- `storage_lvm` (string) - LVM storage, default: "local-lvm"
- `bridge_interface` (string) - Network bridge, default: "vmbr0"
- `vlan_id` (number) - VLAN ID, default: 1
- `cloud_init_vendor_data` (string) - Cloud-init config
- `tags` (list(string)) - Tags to apply

## Outputs

- `vm_id` - VM template ID
- `vm_name` - VM template name
- `node_name` - Proxmox node name
- `template_id` - Full template reference for cloning
- `image_id` - Downloaded image file ID

## Examples

### Ubuntu 22.04 Template

```hcl
module "template_ubuntu" {
  source = "./modules/template"

  node_name        = "pve"
  vm_id            = 9000
  vm_name          = "ubuntu-22-04-template"
  image_url        = "https://cloud-images.ubuntu.com/releases/jammy/release-latest/ubuntu-22.04-server-cloudimg-amd64.img"
  image_filename   = "ubuntu-22.04-server-cloudimg-amd64.img"
  image_checksum   = "5a4d1c..."

  cores            = 2
  memory           = 2048
  disk_size        = 20
}
```

### Debian 12 Template with UEFI

```hcl
module "template_debian" {
  source = "./modules/template"

  node_name                = "pve"
  vm_id                    = 9001
  vm_name                  = "debian-12-template"
  image_url                = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
  image_filename           = "debian-12-generic-amd64.img"
  image_checksum           = "e3b0c4..."
  image_checksum_algorithm = "sha512"

  bios            = "ovmf"
  cores           = 4
  memory          = 4096
  disk_size       = 30
}
```

## Getting Image Checksums

### Debian

```bash
curl -s https://cloud.debian.org/images/cloud/bookworm/latest/SHA512SUMS | \
  grep debian-12-generic-amd64.qcow2
```

### Ubuntu

```bash
curl -s https://cloud-images.ubuntu.com/releases/jammy/release-latest/SHA256SUMS | \
  grep ubuntu-22.04-server-cloudimg-amd64.img
```

## Cloud-Init Customization

The module includes a default cloud-init configuration:

```yaml
#cloud-config
packages:
  - qemu-guest-agent
  - curl
  - wget
package_update: true
power_state:
  mode: reboot
  timeout: 30
```

Override with custom configuration:

```hcl
cloud_init_vendor_data = <<-EOF
  #cloud-config
  packages:
    - qemu-guest-agent
    - vim
    - git
  users:
    - name: ubuntu
      sudo: ALL=(ALL) NOPASSWD:ALL
      ssh_authorized_keys:
        - ssh-rsa AAAA...
EOF
```

## BIOS Configuration

### SEABIOS (Legacy)
- Traditional BIOS
- Better compatibility with older systems
- Default setting

```hcl
bios = "seabios"
```

### OVMF (UEFI)
- Modern UEFI firmware
- Better security features
- Required for some enterprise workloads
- Automatically creates EFI disk

```hcl
bios = "ovmf"
```

## Performance Tuning

```hcl
# High-performance template
module "template_perf" {
  source = "./modules/template"

  # ... other config ...

  cores       = 8
  memory      = 8192
  disk_size   = 100

  # In your VM config from this template,
  # set cache = "writeback" and iothread = true
}
```

## Storage Considerations

- **Image Size**: Typical cloud images are 1-5GB
- **Template Size**: After provisioning, typically 5-10GB
- **Storage Type**: LVM recommended for better performance
- **Disk Space**: Ensure at least 2x template size for clones

## Network Configuration

### Default Network Setup
- Bridge: vmbr0
- Network type: DHCP (via cloud-init)
- VLAN: configurable per environment

### Custom Network

```hcl
module "template" {
  # ... other config ...

  bridge_interface = "vmbr1"
  vlan_id          = 100
}
```

## Lifecycle Management

### Prevent Destruction
Resources are protected with `prevent_destroy`:

```hcl
lifecycle {
  prevent_destroy = true
}
```

To destroy anyway:
```bash
terraform destroy -auto-approve
# When prompted, remove protect_destroy from the code
```

## Troubleshooting

### Image Download Fails
- Check URL is accessible
- Verify checksum algorithm matches image provider
- Check Proxmox node has internet access
- Check datastore has sufficient space

### Template Creation Fails
- Verify SSH connectivity to Proxmox node
- Check API token has required permissions
- Check node name is correct
- Review Proxmox task logs in web UI

### Cloud-Init Not Applied
- Verify vendor_data file exists in snippets
- Check file path format: `local:snippets/vendor-data.yaml`
- Verify cloud-init is installed in image
- Check cloud-init logs: `/var/log/cloud-init/`

## Best Practices

1. **Use Descriptive Names**: Include OS and version in name
2. **Document Image Source**: Keep track of image URLs
3. **Update Regularly**: Download latest security patches
4. **Test Templates**: Clone and verify before production use
5. **Version Control**: Track changes in git
6. **Tag Resources**: Use tags for organization

## Security Considerations

- Images downloaded with checksum verification
- SSH access recommended over passwords
- Cloud-init can inject SSH keys automatically
- Consider enabling SecureBoot with OVMF
- Keep images updated with latest patches

## Integration with VM Module

After creating a template, clone it with the VM module:

```hcl
module "template" {
  source = "./modules/template"
  # ... template config ...
}

module "vm" {
  source = "./modules/vm"

  template_vm_id = module.template.vm_id
  # ... vm config ...
}
```

## References

- [BPG Proxmox Provider Docs](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
- [Proxmox VE VM Creation](https://pve.proxmox.com/wiki/Qemu/KVM_Virtual_Machines)
- [Cloud-Init Documentation](https://cloud-init.io/docs/)
