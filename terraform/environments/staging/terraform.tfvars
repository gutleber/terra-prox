# environments/staging/terraform.tfvars - Staging environment configuration
# Production-like setup with multiple resource types

## Environment
environment  = "staging"
project_name = "proxmox-staging"

## Proxmox Configuration
# Update these values according to your Proxmox setup
node             = "prox01"    # Proxmox node name
datacenter       = "local"     # Datacenter ID
storage_local    = "local"     # Storage for ISOs/backups. For ZFS: use "local-zfs"
storage_vm_disk  = "local-lvm" # Storage for VM disks. For ZFS: use "local-zfs"
bridge_interface = "vmbr0"     # Network bridge
vlan_id          = 2           # Staging VLAN

## Storage & Disk Configuration
disk_cache   = "writeback" # Disk cache: 'writeback' (fast), 'writethrough' (safe), 'unsafe' (fastest)
disk_discard = "on"        # Enable TRIM/DISCARD for SSDs: 'on', 'off', 'ignore'
disk_format  = "raw"       # Disk format: 'raw' (performance), 'qcow2', 'vmdk'
disk_ssd     = true        # Optimize for SSD storage

## VM Templates - Ubuntu and Debian templates
templates = {
  "ubuntu22" = {
    vm_id                    = 9000
    image_url                = "https://cloud-images.ubuntu.com/releases/jammy/release/ubuntu-22.04-server-cloudimg-amd64.img"
    image_filename           = "ubuntu-22.04-server-cloudimg-amd64.img"
    image_checksum           = "aa4b6d2479555774cdcfc4f39fde4d460a842977e8d20d8c7347813baf6b4777" # Get from: curl -s https://cloud-images.ubuntu.com/releases/jammy/release/SHA256SUMS | grep amd64.img
    image_checksum_algorithm = "sha256"
    bios                     = "seabios"
    machine_type             = "q35"
    cores                    = 2
    memory                   = 2048
    disk_size                = 20
  }

  "debian12" = {
    vm_id                    = 9001
    image_url                = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
    image_filename           = "debian-12-generic-amd64.img"
    image_checksum           = "5da221d8f7434ee86145e78a2c60ca45eb4ef8296535e04f6f333193225792aa8ceee3df6aea2b4ee72d6793f7312308a8b0c6a1c7ed4c7c730fa7bda1bc665f"
    image_checksum_algorithm = "sha512"
    bios                     = "seabios"
    machine_type             = "q35"
    cores                    = 2
    memory                   = 2048
    disk_size                = 20
  }
}

## VMs Configuration - Web, App, and Database servers
vm_configs = [
  # Web Server
  {
    name              = "staging-web-01"
    template          = "ubuntu22"
    vm_id             = 100
    cores             = 2
    memory            = 2048
    disk_size         = 20
    autostart         = true
    enable_cloud_init = true
    cloud_init_user   = "ubuntu"

    network_devices = [
      {
        bridge  = "vmbr0"
        vlan_id = 2 # Staging VLAN
      }
    ]

    ip_configs = [
      {
        ipv4_address = "192.168.2.10/24"
        ipv4_gateway = "192.168.2.1"
      }
    ]

    additional_disks = []

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

    tags = ["staging", "web", "production-like"]
  },

  # Application Server
  {
    name              = "staging-app-01"
    template          = "debian12"
    vm_id             = 101
    cores             = 4
    memory            = 4096
    disk_size         = 50
    autostart         = true
    enable_cloud_init = true
    cloud_init_user   = "debian"

    network_devices = [
      {
        bridge  = "vmbr0"
        vlan_id = 2
      }
    ]

    ip_configs = [
      {
        ipv4_address = "192.168.2.20/24"
        ipv4_gateway = "192.168.2.1"
      }
    ]

    additional_disks = [
      merge(local.default_disk_config, {
        interface = "scsi1"
        size      = 100
      })
    ]

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
        source    = "192.168.2.10" # From web server
        comment   = "App port from web"
      }
    ]

    tags = ["staging", "app", "database"]
  },

  # Database Server
  {
    name              = "staging-db-01"
    template          = "debian12"
    vm_id             = 102
    cores             = 4
    memory            = 8192
    disk_size         = 100
    autostart         = true
    enable_cloud_init = true
    cloud_init_user   = "debian"

    network_devices = [
      {
        bridge  = "vmbr0"
        vlan_id = 2
      }
    ]

    ip_configs = [
      {
        ipv4_address = "192.168.2.30/24"
        ipv4_gateway = "192.168.2.1"
      }
    ]

    additional_disks = [
      merge(local.default_disk_config, {
        interface = "scsi1"
        size      = 500
      })
    ]

    enable_firewall = true
    firewall_rules = [
      {
        action    = "ACCEPT"
        direction = "IN"
        protocol  = "tcp"
        port      = "22"
        source    = "192.168.2.0/24"
        comment   = "SSH from network"
      },
      {
        action    = "ACCEPT"
        direction = "IN"
        protocol  = "tcp"
        port      = "3306"
        source    = "192.168.2.20" # From app server
        comment   = "MySQL from app"
      },
      {
        action    = "ACCEPT"
        direction = "IN"
        protocol  = "tcp"
        port      = "5432"
        source    = "192.168.2.20" # From app server
        comment   = "PostgreSQL from app"
      }
    ]

    tags = ["staging", "database", "critical"]
  }
]

## LXC Containers - Support services
lxc_configs = [
  {
    name              = "staging-monitor-01"
    container_id      = 200
    template_file_id  = "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst" # Update with your actual template ID from Proxmox
    os_type           = "debian"
    storage           = "local-lvm"
    disk_size         = 20
    cores             = 2
    memory            = 1024
    memory_swap       = 1024
    autostart         = true
    unprivileged      = true
    startup_order     = 1

    network_devices = [
      {
        name    = "eth0"
        bridge  = "vmbr0"
        vlan_id = 2
      }
    ]

    ip_configs = [
      {
        ipv4_address = "dhcp"
      }
    ]

    dns_servers     = ["8.8.8.8", "8.8.4.4"]
    ssh_public_keys = []
    root_password   = null

    enable_firewall = true
    firewall_rules = [
      {
        type    = "in"
        action  = "ACCEPT"
        proto   = "tcp"
        dport   = "9090"
        source  = "192.168.2.0/24"
        comment = "Prometheus"
      }
    ]

    tags = ["staging", "monitoring"]
  }
]

## Common Tags
tags = {
  Environment = "staging"
  ManagedBy   = "Terraform"
  Owner       = "DevOps"
  Purpose     = "Pre-production"
}
