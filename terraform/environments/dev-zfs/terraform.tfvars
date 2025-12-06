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

## Proxmox Configuration - ZFS RAID1 Setup
# Update node name and bridge if different from your setup
node             = "prox01"    # Your Proxmox node name (e.g., 'pve', 'proxmox1', 'pve1')
datacenter       = "local"     # Datacenter ID (usually 'local')
storage_local    = "local-zfs" # ZFS storage for ISOs, backups, snippets
storage_vm_disk  = "local-zfs" # ZFS storage for VM disks (same pool for simplicity)
bridge_interface = "vmbr0"     # Network bridge interface name
vlan_id          = 1           # Default VLAN ID

## Storage & Disk Configuration (for ZFS)
disk_cache   = "writeback" # Disk cache: 'writeback' (fast), 'writethrough' (safe), 'unsafe' (fastest)
disk_discard = "on"        # Enable TRIM/DISCARD for SSDs: 'on', 'off', 'ignore'
disk_format  = "raw"       # Disk format: 'raw' (performance), 'qcow2', 'vmdk'
disk_ssd     = true        # Optimize for SSD storage

## Disk Defaults (via Terraform Locals)
# These defaults inherit from the root-level variables defined above
# They can be overridden per-disk using merge(local.default_disk_config, {field = value})
locals {
  default_disk_config = {
    datastore_id = var.storage_vm_disk # Inherits from storage_vm_disk variable above (local-zfs)
    file_format  = var.disk_format     # Inherits from disk_format variable
    cache        = var.disk_cache      # Inherits from disk_cache variable
    ssd          = var.disk_ssd        # Inherits from disk_ssd variable
    discard      = var.disk_discard    # Inherits from disk_discard variable
  }
}

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
  }
}

## VMs Configuration - Create multiple VMs with different parameters
# Each VM references a template and customizes it
# All VMs will use local-zfs storage
vm_configs = [
  {
    name              = "dev-web-01"
    template          = "ubuntu22" # Reference the template key
    vm_id             = 100
    cores             = 2
    memory            = 2048
    disk_size         = 20
    autostart         = false
    enable_cloud_init = true
    cloud_init_user   = "ubuntu"

    network_devices = [
      {
        bridge  = "vmbr0"
        vlan_id = 1
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
    name              = "dev-app-01"
    template          = "debian12" # Different template
    vm_id             = 101
    cores             = 2
    memory            = 1024
    disk_size         = 15
    autostart         = false
    enable_cloud_init = true
    cloud_init_user   = "debian"

    network_devices = [
      {
        bridge  = "vmbr0"
        vlan_id = 1
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
lxc_configs = [
  {
    name         = "dev-monitor-01"
    container_id = 200
    os_type      = "debian"
    os_version   = "12"
    storage      = "local-zfs" # ZFS storage for container
    disk_size    = 10
    memory       = 512
    memory_swap  = 1024
    cores        = 2
    unprivileged = true
    autostart    = false

    network_devices = [
      {
        bridge = "vmbr0"
        vlan   = 1
        mtu    = 1500
      }
    ]

    dns_servers     = []
    enable_firewall = false
    firewall_rules  = []
    tags            = ["dev", "monitoring"]
  }
]

# Common tags for all resources
tags = {
  ManagedBy = "Terraform"
  Project   = "Proxmox-ZFS"
  Storage   = "ZFS-RAID1"
}
