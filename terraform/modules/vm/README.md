# VM Module

Creates and manages virtual machines by cloning from Proxmox templates.

## Purpose

This module handles the lifecycle of VMs by cloning existing templates and customizing them with specific configurations.

## Features

- Clone VMs from existing templates
- Configure CPU, memory, and additional disks
- Apply cloud-init customization with automatic LVM root filesystem expansion
- Network device configuration with firewall enforcement
- **Security-first firewall configuration** (default deny inbound, allow outbound)
- Firewall logging and policy management
- Memory ballooning for efficient resource usage
- Startup ordering for coordinated multi-VM deployments
- Serial device for debugging boot issues
- Operating system type configuration
- Automatic cloud-init lifecycle management

## Usage

```hcl
module "vm" {
  source = "./modules/vm"

  node_name      = "pve"
  vm_id          = 9100
  vm_name        = "web-server-01"
  template_vm_id = 9000

  cores          = 2
  memory         = 2048
  autostart      = false
}
```

## Resources

### proxmox_virtual_environment_vm
- Clones from template
- Configures resources (CPU, memory)
- Applies network and cloud-init config

### proxmox_virtual_environment_firewall_rules
- Optional firewall configuration
- Manages inbound/outbound rules

## Variables

### Required

- `node_name` (string) - Proxmox node name
- `vm_id` (number) - VM ID
- `vm_name` (string) - VM name
- `template_vm_id` (number) - Template VM ID to clone from

### Optional with Defaults

- `cores` (number) - CPU cores, default: 2
- `memory` (number) - Memory in MB, default: 2048
- `memory_ballooning` (bool) - Enable memory ballooning (floating = dedicated/2), default: true
- `autostart` (bool) - Auto-start on boot, default: false
- `enable_cloud_init` (bool) - Enable cloud-init, default: true
- `cloud_init_user` (string) - Cloud-init user, default: "debian"
- `ssh_public_keys` (list) - SSH keys for cloud-init
- `os_type` (string) - Operating system type (l26=Linux, w=Windows), default: "l26"
- `ip_configs` (list) - IP configuration
- `network_devices` (list) - Network devices
- `additional_disks` (list) - Extra disks to attach
- `startup_order` (number) - Startup order for coordinated VM startup (null = no ordering)
- `startup_up_delay` (number) - Delay before starting next VM in sequence, default: 10
- `startup_down_delay` (number) - Delay during shutdown sequence, default: 10
- `enable_lvm_auto_resize` (bool) - Auto-expand LVM root filesystem on boot, default: true
- `enable_firewall` (bool) - Enable firewall and network interface enforcement, default: false
- `firewall_log_level` (string) - Firewall log level (info, nolog, alert, audit), default: "info"
- `firewall_rules` (list) - Firewall rules
- `tags` (list) - Resource tags

## Outputs

- `vm_id` - VM ID
- `vm_name` - VM name
- `node_name` - Proxmox node
- `ip_address` - Primary IP (if configured)
- `status` - VM status

## Examples

### Basic VM Clone

```hcl
module "web_server" {
  source = "./modules/vm"

  node_name      = "pve"
  vm_id          = 9100
  vm_name        = "web-01"
  template_vm_id = 9000

  autostart = true
}
```

### VM with Network Configuration

```hcl
module "app_server" {
  source = "./modules/vm"

  node_name      = "pve"
  vm_id          = 9101
  vm_name        = "app-01"
  template_vm_id = 9000

  cores   = 4
  memory  = 4096

  network_devices = [
    {
      bridge  = "vmbr0"
      vlan_id = 100
    },
    {
      bridge  = "vmbr1"
      vlan_id = 101
    }
  ]

  ip_configs = [
    {
      ipv4_address = "192.168.1.100"
      ipv4_gateway = "192.168.1.1"
    }
  ]

  ssh_public_keys = [
    file("~/.ssh/id_rsa.pub")
  ]
}
```

### VM with Additional Disks

```hcl
module "db_server" {
  source = "./modules/vm"

  node_name      = "pve"
  vm_id          = 9102
  vm_name        = "db-01"
  template_vm_id = 9000

  cores   = 8
  memory  = 8192

  additional_disks = [
    {
      datastore_id = "local-lvm"
      interface    = "scsi1"
      size         = 100
      file_format  = "raw"
      cache        = "writeback"
      ssd          = true
    }
  ]
}
```

### VM with Firewall Rules

```hcl
module "api_server" {
  source = "./modules/vm"

  node_name      = "pve"
  vm_id          = 9103
  vm_name        = "api-01"
  template_vm_id = 9000

  enable_firewall = true

  firewall_rules = [
    {
      action    = "ACCEPT"
      direction = "IN"
      protocol  = "tcp"
      port      = "22"
      comment   = "SSH"
    },
    {
      action    = "ACCEPT"
      direction = "IN"
      protocol  = "tcp"
      port      = "80"
      comment   = "HTTP"
    },
    {
      action    = "ACCEPT"
      direction = "IN"
      protocol  = "tcp"
      port      = "443"
      comment   = "HTTPS"
    }
  ]
}
```

## Cloud-Init Configuration

### Default Behavior
- Applies cloud-init vendor data from template
- Can be customized per VM

### Custom User Data

```hcl
# In main.tf, add custom cloud-init
initialization {
  user_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl start nginx
  EOF)
}
```

## Network Configuration

### DHCP (Default)
```hcl
ip_configs = [
  {
    ipv4_address = "dhcp"
  }
]
```

### Static IP
```hcl
ip_configs = [
  {
    ipv4_address = "192.168.1.100/24"
    ipv4_gateway = "192.168.1.1"
  }
]
```

### IPv6 Support
```hcl
ip_configs = [
  {
    ipv4_address = "192.168.1.100/24"
    ipv4_gateway = "192.168.1.1"
    ipv6_address = "2001:db8::100/64"
    ipv6_gateway = "2001:db8::1"
  }
]
```

## Disk Management

### Additional Disks

```hcl
additional_disks = [
  {
    datastore_id = "local-lvm"
    interface    = "scsi1"
    size         = 50
    file_format  = "raw"
    cache        = "writeback"
    ssd          = true
    discard      = "on"
  }
]
```

### Disk Configuration

- `datastore_id` - Storage location
- `interface` - SCSI, SATA, or IDE interface
- `size` - Size in GB
- `file_format` - "raw" or "qcow2"
- `cache` - "writeback" (default), "writethrough", "unsafe"
- `ssd` - Enable SSD optimization
- `discard` - Enable TRIM/discard

## Firewall Rules

### Security-First Design

This module implements **security-first firewall configuration** based on best practices from production Proxmox deployments:

- **Default Deny Inbound**: Blocks all inbound traffic by default (`input_policy = "DROP"`)
- **Default Allow Outbound**: Allows all outbound traffic by default (`output_policy = "ACCEPT"`)
- **Firewall Enforcement**: Network interfaces have firewall enforcement enabled
- **Logging**: All firewall traffic is logged (configurable level: info, nolog, alert, audit)

This means you must explicitly allow the traffic you need, rather than the reverse.

### How Firewall Works

The firewall configuration uses three components:

1. **`enable_firewall = true`** - Enables firewall on the VM
   - Enables firewall options (policy, logging)
   - Enables firewall enforcement on all network interfaces (`firewall = true`)
   - Creates firewall rules resource

2. **`proxmox_virtual_environment_firewall_options`** - Firewall security policy
   - Default deny inbound, allow outbound
   - Logging configured for security monitoring
   - DHCP and IPv6 (NDP/RADV) enabled

3. **`firewall_rules = [...]`** - Defines the actual firewall rules
   - Only created/applied if `enable_firewall = true`
   - Rules define which specific traffic is ACCEPT or DROP
   - Evaluated against the default deny policy

### Rule Format

```hcl
{
  action      = "ACCEPT" or "DROP"
  direction   = "IN" or "OUT"
  protocol    = "tcp", "udp", "icmp"
  port        = "80" or "80:90" for range
  source      = "192.168.0.0/24" or "0.0.0.0/0"
  destination = IP/CIDR or empty
  comment     = "Descriptive text"
}
```

### Common Rules

```hcl
# SSH
{
  action    = "ACCEPT"
  direction = "IN"
  protocol  = "tcp"
  port      = "22"
  comment   = "SSH"
}

# HTTP/HTTPS
{
  action    = "ACCEPT"
  direction = "IN"
  protocol  = "tcp"
  port      = "80"
  comment   = "HTTP"
},
{
  action    = "ACCEPT"
  direction = "IN"
  protocol  = "tcp"
  port      = "443"
  comment   = "HTTPS"
}

# All outbound
{
  action    = "ACCEPT"
  direction = "OUT"
  comment   = "Allow all outbound"
}
```

## Advanced Features

### LVM Auto-Resize (Critical for Disk Resizing)

**Problem Solved**: When cloning a template and increasing disk size, the VM's root filesystem doesn't automatically expand.

**Solution**: LVM auto-resize uses cloud-init to automatically expand the root filesystem on first boot:

```bash
runcmd:
  - growpart /dev/vda 3          # Expand partition
  - pvresize /dev/vda3           # Resize physical volume
  - lvextend -l +100%FREE /dev/mapper/pve-root  # Expand logical volume
  - resize2fs /dev/mapper/pve-root               # Resize filesystem
```

**Enable** (default: true):
```hcl
enable_lvm_auto_resize = true
```

**Disable** if using different partitioning:
```hcl
enable_lvm_auto_resize = false
```

### Memory Ballooning

By default, VMs have memory ballooning enabled. This allows the hypervisor to reclaim unused memory:

```hcl
memory {
  dedicated = 2048              # Guaranteed memory
  floating  = 1024              # Ballooning: can shrink to this (50% of dedicated)
}
```

**Disable** for guaranteed memory:
```hcl
memory_ballooning = false       # floating = dedicated (no ballooning)
```

### Startup Ordering

Coordinate multi-VM startup/shutdown sequences:

```hcl
startup_order      = 10         # Start this VM in position 10
startup_up_delay   = 10         # Wait 10s before starting next VM
startup_down_delay = 10         # Wait 10s during shutdown
```

### Serial Device

Debugging boot issues:
- VM has serial console enabled by default
- Access via Proxmox web UI or `qm terminal <vm_id>`
- Helps troubleshoot boot problems

## Multiple VMs

Create multiple similar VMs using count:

```hcl
variable "web_server_count" {
  default = 3
}

module "web_servers" {
  source   = "./modules/vm"
  count    = var.web_server_count

  node_name      = "pve"
  vm_id          = 9100 + count.index
  vm_name        = "web-${format("%02d", count.index + 1)}"
  template_vm_id = 9000

  cores  = 2
  memory = 2048
}
```

## Accessing VMs

### SSH Connection

```bash
# Using cloud-init user (debian for Debian/Ubuntu)
ssh -i ~/.ssh/id_rsa debian@<vm-ip>

# Using root (if configured)
ssh -i ~/.ssh/id_rsa root@<vm-ip>
```

### Via Proxmox Console

Access through Proxmox web UI:
1. Select VM
2. Click "Console" tab
3. Use SPICE or VNC viewer

## Troubleshooting

### VM Won't Start
- Check Proxmox node resources
- Verify template VM exists and is marked as template
- Check for storage space

### Network Not Working
- Verify network_device bridge exists
- Check cloud-init ip_config
- Verify VLAN is configured on bridge

### Cloud-Init Not Applied
- Check initialization block is correct
- Verify cloud-init is installed in template
- Check `/var/log/cloud-init/` in VM

### Can't SSH to VM
- Verify SSH key is injected via cloud-init
- Check firewall rules allow port 22
- Try Proxmox console to debug

## Best Practices

1. **Use Templates**: Always clone from templates, never create VMs directly
2. **Document Configuration**: Comment on custom settings
3. **Resource Limits**: Don't over-allocate resources
4. **Naming Convention**: Use consistent, descriptive names
5. **Security-First Firewall**: Enable firewall by default, whitelist necessary traffic
6. **LVM Auto-Resize**: Keep enabled (default) for automatic disk expansion
7. **Memory Ballooning**: Use for efficient resource sharing, disable if guaranteed memory needed
8. **Startup Ordering**: Use for coordinated multi-VM deployments (databases, load balancers, etc.)
9. **Backups**: Implement regular backup strategy
10. **Monitoring**: Setup monitoring for resource usage
11. **OS Type**: Set correct OS type (l26 for Linux, w for Windows) for proper optimizations

## Integration

### With Template Module
```hcl
module "template" {
  source = "./modules/template"
  # ...
}

module "vm" {
  source = "./modules/vm"
  template_vm_id = module.template.vm_id
  # ...
}
```

## References

- [BPG Proxmox Provider VM Docs](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm)
- [Cloud-Init Documentation](https://cloud-init.io/)
