# environments/dev-zfs/terraform.tfvars - Development environment with ZFS RAID1
# Example configuration for Proxmox VE 9.1.1 with ZFS storage
#
# This example assumes:
# - Proxmox VE 9.1.1 with ZFS RAID1 setup
# - Single ZFS pool named "local-zfs"
# - vmbr0 network bridge configured
# - pve node name

## Environment
environment  = "dev"
project_name = "proxmox-dev-zfs"

## Proxmox Configuration - ZFS RAID1 Setup (Mixed Storage)
# Update node name and bridge if different from your setup
node             = "prox01"    # Your Proxmox node name (e.g., 'pve', 'proxmox1', 'pve1')
datacenter       = "local"     # Datacenter ID (usually 'local')
storage_local    = "files"     # Directory storage for ISOs (has image/iso support)
storage_snippets = "local"     # Directory storage for cloud-init snippets (has snippets support)
storage_vm_disk  = "local-zfs" # ZFS storage for VM disks and containers
bridge_interface = "vlan34"    # Network bridge interface name (use existing VLAN interface, same as working VM 300)
vlan_id          = null        # VLAN ID (null when using dedicated VLAN interface)

## Storage & Disk Configuration (for ZFS)
disk_cache   = "writeback" # Disk cache: 'writeback' (fast), 'writethrough' (safe), 'unsafe' (fastest)
disk_discard = "on"        # Enable TRIM/DISCARD for SSDs: 'on', 'off', 'ignore'
disk_format  = "raw"       # Disk format: 'raw' (performance), 'qcow2', 'vmdk'
disk_ssd     = true        # Optimize for SSD storage

## VM Templates - Define reusable templates for cloning
# Both templates will be stored on local-zfs
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
    cloud_init_vendor_data   = <<-EOT
      #cloud-config
      # Update system packages
      package_update: true
      package_upgrade: true
      packages:
        - curl
        - wget
        - git
        - vim
        - qemu-guest-agent

      # Set timezone
      timezone: Europe/Bratislava

      # Configure hostname
      hostname: ubuntu-template

      # Run custom commands
      runcmd:
        - echo "Ubuntu 22.04 template configured by Terraform"
    EOT
  }

  "debian12" = {
    vm_id                    = 9001
    image_url                = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
    image_filename           = "debian-12-generic-amd64.img"
    image_checksum           = "5da221d8f7434ee86145e78a2c60ca45eb4ef8296535e04f6f333193225792aa8ceee3df6aea2b4ee72d6793f7312308a8b0c6a1c7ed4c7c730fa7bda1bc665f" # Get from: curl -s https://cloud.debian.org/images/cloud/bookworm/latest/SHA512SUMS | grep amd64.qcow2
    image_checksum_algorithm = "sha512"
    bios                     = "seabios"
    machine_type             = "q35"
    cores                    = 2
    memory                   = 2048
    disk_size                = 20
    cloud_init_vendor_data   = <<-EOT
      #cloud-config
      # Update system packages
      package_update: true
      package_upgrade: true
      packages:
        - curl
        - wget
        - git
        - vim
        - qemu-guest-agent

      # Set timezone
      timezone: Europe/Bratislava

      # Run custom commands
      runcmd:
        - echo "Debian 12 template configured by Terraform"
    EOT
  }
}

## VMs Configuration - Create multiple VMs with different parameters
# Each VM references a template and customizes it
# All VMs will use local-zfs storage
vm_configs = [
  {
    name                   = "dev-web-01"
    template               = "ubuntu22" # Reference the template key
    vm_id                  = 100
    cores                  = 2
    memory                 = 2048
    disk_size              = 20
    autostart              = false
    enable_cloud_init      = true
    enable_lvm_auto_resize = true # Enable LVM auto-resize on disk expansion
    cloud_init_user        = "ubuntu"

    network_devices = [
      {
        bridge  = "vlan34"
        vlan_id = null
      }
    ]

    ip_configs = [
      {
        ipv4_address = "dhcp"
      }
    ]

    additional_disks = []
    enable_firewall  = false
    firewall_rules   = []
    tags             = ["dev", "web"]
  },

  {
    name                   = "dev-app-01"
    template               = "debian12" # Different template
    vm_id                  = 101
    cores                  = 2
    memory                 = 1024
    disk_size              = 15
    autostart              = false
    enable_lvm_auto_resize = true # Enable LVM auto-resize on disk expansion
    enable_cloud_init      = true
    cloud_init_user        = "debian"

    network_devices = [
      {
        bridge  = "vlan34"
        vlan_id = null
      }
    ]

    ip_configs = [
      {
        ipv4_address = "dhcp"
      }
    ]

    additional_disks = []
    enable_firewall  = false
    firewall_rules   = []
    tags             = ["dev", "app"]
  }
]

## LXC Container Configuration
# lxc_configs = [
#   {
#     name              = "dev-monitor-01"
#     container_id      = 200
#     template_file_id  = "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst" # Update with your actual template ID from Proxmox
#     os_type           = "debian"
#     storage           = "local-zfs" # ZFS storage for container
#     disk_size         = 10
#     memory            = 512
#     memory_swap       = 1024
#     cores             = 2
#     unprivileged      = true
#     autostart         = false

#     network_devices = [
#       {
#         name    = "eth0"
#         bridge  = "vmbr0"
#         vlan_id = 1
#       }
#     ]

#     ip_configs = [
#       {
#         ipv4_address = "dhcp"
#       }
#     ]

#     dns_servers     = ["8.8.8.8", "8.8.4.4"]
#     enable_firewall = false
#     firewall_rules  = []
#     tags            = ["dev", "monitoring"]
#   }
# ]

# Common tags for all resources
tags = {
  ManagedBy = "Terraform"
  Project   = "Proxmox-ZFS"
  Storage   = "ZFS-RAID1"
}
