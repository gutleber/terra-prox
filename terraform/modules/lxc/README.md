# LXC Module

Creates and manages lightweight Linux containers in Proxmox.

## Purpose

This module provisions LXC containers, which are lighter-weight alternatives to full VMs, consuming fewer resources while maintaining good isolation.

## Features

- Support for multiple Linux distributions (Debian, Ubuntu, Alpine, etc.)
- Lightweight compared to full VMs
- Unprivileged mode by default (more secure)
- Resource allocation (CPU, memory, disk)
- Network configuration
- SSH key injection
- Optional firewall rules
- Fast provisioning and startup

## Usage

```hcl
module "lxc" {
  source = "./modules/lxc"

  node_name     = "pve"
  container_id  = 200
  container_name = "app-container"

  os_type   = "debian"
  os_version = "12"
}
```

## Resources

### proxmox_virtual_environment_container
- Creates LXC container
- Configures OS, resources, network
- Manages SSH keys and users

### proxmox_virtual_environment_firewall_rules
- Optional firewall configuration
- Manages inbound/outbound rules

## Variables

### Required

- `node_name` (string) - Proxmox node name
- `container_id` (number) - Container ID
- `container_name` (string) - Container hostname

### Optional with Defaults

- `os_type` (string) - OS type, default: "debian"
- `os_version` (string) - OS version, default: "12"
- `storage` (string) - Storage datastore, default: "local-lvm"
- `disk_size` (number) - Disk size GB, default: 10
- `volume_size` (number) - Volume size GB, default: 10
- `cores` (number) - CPU cores, default: 1
- `cpu_units` (number) - CPU units, default: 1024
- `memory` (number) - Memory MB, default: 512
- `memory_swap` (number) - Swap MB, default: 512
- `network_devices` (list) - Network configuration
- `dns_servers` (list) - DNS servers
- `ssh_public_keys` (list) - SSH keys
- `root_password` (string) - Root password (not recommended)
- `autostart` (bool) - Auto-start on boot, default: false
- `unprivileged` (bool) - Unprivileged mode, default: true
- `startup_order` (number) - Startup order, default: 0
- `enable_firewall` (bool) - Enable firewall, default: false
- `tags` (list) - Resource tags

## Outputs

- `container_id` - Container ID
- `container_name` - Container hostname
- `node_name` - Proxmox node
- `status` - Container status
- `ip_address` - Primary IP address

## Examples

### Basic Debian Container

```hcl
module "debian_container" {
  source = "./modules/lxc"

  node_name     = "pve"
  container_id  = 200
  container_name = "debian-app"

  os_type    = "debian"
  os_version = "12"
}
```

### Ubuntu Container with Custom Resources

```hcl
module "ubuntu_container" {
  source = "./modules/lxc"

  node_name      = "pve"
  container_id   = 201
  container_name = "ubuntu-web"

  os_type    = "ubuntu"
  os_version = "22.04"

  cores        = 4
  memory       = 2048
  memory_swap  = 2048
  disk_size    = 50
}
```

### Alpine Container with SSH Keys

```hcl
module "alpine_container" {
  source = "./modules/lxc"

  node_name      = "pve"
  container_id   = 202
  container_name = "alpine-lightweight"

  os_type    = "alpine"
  os_version = "3.18"

  cores   = 1
  memory  = 256
  disk_size = 5

  unprivileged = true

  ssh_public_keys = [
    file("~/.ssh/id_rsa.pub")
  ]

  autostart = true
}
```

### Container with Network Configuration

```hcl
module "network_container" {
  source = "./modules/lxc"

  node_name      = "pve"
  container_id   = 203
  container_name = "network-aware"

  os_type = "debian"

  network_devices = [
    {
      name    = "eth0"
      bridge  = "vmbr0"
      vlan_id = 100
    },
    {
      name    = "eth1"
      bridge  = "vmbr1"
      vlan_id = 101
    }
  ]

  dns_servers = [
    "8.8.8.8",
    "8.8.4.4",
    "1.1.1.1"
  ]
}
```

### Container with Firewall

```hcl
module "secure_container" {
  source = "./modules/lxc"

  node_name      = "pve"
  container_id   = 204
  container_name = "secure-app"

  os_type = "debian"

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
      port      = "8080"
      source    = "192.168.1.0/24"
      comment   = "App port (internal)"
    },
    {
      action    = "ACCEPT"
      direction = "OUT"
      comment   = "Allow all outbound"
    },
    {
      action    = "DROP"
      direction = "IN"
      comment   = "Drop all other inbound"
    }
  ]
}
```

## Supported Operating Systems

- **Debian**: 11, 12 (latest)
- **Ubuntu**: 20.04 LTS, 22.04 LTS, 24.04 LTS
- **Alpine**: 3.17, 3.18, 3.19, latest
- **Alma**: 8, 9
- **Rocky**: 8, 9

### OS Type Examples

```hcl
# Debian
os_type    = "debian"
os_version = "12"

# Ubuntu
os_type    = "ubuntu"
os_version = "22.04"

# Alpine
os_type    = "alpine"
os_version = "3.18"

# Alma
os_type    = "alma"
os_version = "9"

# Rocky
os_type    = "rocky"
os_version = "9"
```

## Privileged vs Unprivileged

### Unprivileged (Default, Recommended)

More secure, recommended for most use cases:

```hcl
unprivileged = true  # Default
```

Benefits:
- Better isolation
- User namespace separation
- Safer against privilege escalation
- Can't use some privileged operations

### Privileged

Less secure but with more capabilities:

```hcl
unprivileged = false
```

Use only if:
- Application requires specific kernel features
- Backwards compatibility needed
- You understand security implications

## SSH Access

### Inject SSH Keys

```hcl
module "container" {
  source = "./modules/lxc"

  # ... other config ...

  ssh_public_keys = [
    file("~/.ssh/id_rsa.pub"),
    "ssh-rsa AAAA... user@host"
  ]
}
```

### SSH into Container

```bash
# Get container IP from Proxmox web UI
ssh -i ~/.ssh/id_rsa root@<container-ip>

# Or via container hostname (if DNS configured)
ssh -i ~/.ssh/id_rsa root@<container-name>
```

## Network Configuration

### Default (DHCP)

```hcl
network_devices = [
  {
    name   = "eth0"
    bridge = "vmbr0"
  }
]
```

### Multiple Interfaces

```hcl
network_devices = [
  {
    name    = "eth0"
    bridge  = "vmbr0"
    vlan_id = 100
  },
  {
    name    = "eth1"
    bridge  = "vmbr1"
    vlan_id = 101
  }
]
```

### Static IP (via Cloud-Init in Template)

In Proxmox, configure static IP on container:
1. Select container
2. Network tab
3. Configure static IP

Or use cloud-init in container startup script.

## Resource Allocation

### Lightweight Container

```hcl
cores       = 1
cpu_units   = 512
memory      = 256
memory_swap = 256
disk_size   = 5
```

### Standard Container

```hcl
cores       = 2
cpu_units   = 1024
memory      = 1024
memory_swap = 1024
disk_size   = 20
```

### Heavy Workload Container

```hcl
cores       = 4
cpu_units   = 2048
memory      = 4096
memory_swap = 4096
disk_size   = 100
```

### CPU Units

CPU units determine CPU share in container:
- 1024 = 1 core equivalent
- 512 = 0.5 core equivalent
- Adjust based on workload needs

## Startup Configuration

### Startup Order

Control boot sequence across multiple containers:

```hcl
startup_order = 1    # Start first
startup_order = 2    # Start second
startup_order = 0    # Don't auto-start (default)
```

### Delays

```hcl
startup_delay  = 30   # Wait 30s before starting
shutdown_delay = 60   # Wait 60s during shutdown
```

## Firewall Rules

### How Firewall Works

The firewall configuration uses two components:

1. **`enable_firewall = true`** - Enables firewall enforcement on all network interfaces
   - When enabled, each network device gets `firewall = true`
   - When disabled, each network device gets `firewall = false`

2. **`firewall_rules = [...]`** - Defines the actual firewall rules
   - Only created/applied if `enable_firewall = true`
   - Rules define which traffic is ACCEPT or DROP

### Rule Format

```hcl
{
  action      = "ACCEPT" or "DROP"
  direction   = "IN" or "OUT"
  protocol    = "tcp", "udp", "icmp"
  port        = "80" or "80:90" for range
  source      = "192.168.0.0/24"
  destination = "192.168.1.0/24"
  comment     = "Descriptive text"
}
```

### Common Rules

```hcl
# Allow SSH
{
  action    = "ACCEPT"
  direction = "IN"
  protocol  = "tcp"
  port      = "22"
  comment   = "SSH"
}

# Allow HTTP/HTTPS
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

# Restrict to specific source
{
  action    = "ACCEPT"
  direction = "IN"
  protocol  = "tcp"
  port      = "3306"
  source    = "192.168.1.100"
  comment   = "MySQL from app server"
}
```

## Multiple Containers

Create multiple containers with count:

```hcl
variable "container_count" {
  default = 3
}

module "app_containers" {
  source   = "./modules/lxc"
  count    = var.container_count

  node_name      = "pve"
  container_id   = 300 + count.index
  container_name = "app-${format("%02d", count.index + 1)}"

  os_type = "debian"
  cores   = 2
  memory  = 1024
}
```

## Container Commands

Access container via Proxmox:

```bash
# Console access
pve-console <container-id>

# Execute command
pct exec <container-id> -- <command>

# Shutdown
pct shutdown <container-id>

# Start
pct start <container-id>

# List containers
pct list
```

## Troubleshooting

### Container Won't Start
- Check node has resources available
- Verify OS type/version combination
- Check Proxmox task logs

### Network Not Working
- Verify bridge exists on node
- Check container network config
- Test DNS resolution

### Can't SSH
- Verify SSH keys are injected
- Check network connectivity
- Try console access to debug

### High Resource Usage
- Check process list in container
- Adjust memory/CPU allocation
- Monitor from Proxmox web UI

## Best Practices

1. **Use Unprivileged**: Default secure mode unless required
2. **SSH Keys**: Prefer SSH keys over passwords
3. **Resource Limits**: Monitor and adjust allocations
4. **Updates**: Keep OS updated with patches
5. **Naming**: Use consistent naming conventions
6. **Backups**: Implement container backup strategy
7. **Monitoring**: Setup monitoring for containers
8. **Isolation**: Use VLAN/firewall for segmentation

## Performance Comparison

| Aspect | VM | LXC Container |
|--------|----|----|
| Boot Time | 30-60s | 2-5s |
| Memory | 512MB+ | 64MB+ |
| CPU Overhead | 5-10% | 1-2% |
| Disk Space | 5-50GB | 1-10GB |
| Isolation | Full | Good |
| Use Case | Complex apps | Simple services |

## References

- [BPG Proxmox Provider LXC Docs](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_container)
- [Proxmox LXC Documentation](https://pve.proxmox.com/wiki/Linux_Container)
- [LXC Project](https://linuxcontainers.org/)
