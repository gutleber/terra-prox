# environments/dev/terraform.tfvars - Development environment configuration
# Multi-VM/LXC configuration with per-resource customization

## Environment
environment  = "dev"
project_name = "proxmox-dev"

## Proxmox Configuration
# Update these values according to your Proxmox setup
node             = "prox01"    # Proxmox node name (e.g., 'pve', 'proxmox1', 'pve1')
datacenter       = "local"     # Datacenter ID (usually 'local')
storage_local    = "local"     # Storage for ISOs/backups. For ZFS: use "local-zfs"
storage_vm_disk  = "local-lvm" # Storage for VM disks. For ZFS: use "local-zfs"
bridge_interface = "vmbr0"     # Network bridge (e.g., 'vmbr0', 'vmbr1')
vlan_id          = 1           # Default VLAN ID

## Storage & Disk Configuration
disk_cache   = "writeback" # Disk cache: 'writeback' (fast), 'writethrough' (safe), 'unsafe' (fastest)
disk_discard = "on"        # Enable TRIM/DISCARD for SSDs: 'on', 'off', 'ignore'
disk_format  = "raw"       # Disk format: 'raw' (performance), 'qcow2', 'vmdk'
disk_ssd     = true        # Optimize for SSD storage

## VM Templates - Define reusable templates for cloning
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

## LXC Containers - Create lightweight containers
lxc_configs = [
  {
    name              = "dev-container-01"
    container_id      = 200
    template_file_id  = "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst" # Update with your actual template ID from Proxmox
    os_type           = "debian"
    storage           = "local-lvm"
    disk_size         = 10
    cores             = 1
    memory            = 256
    memory_swap       = 256
    autostart         = false
    unprivileged      = true
    startup_order     = 0

    network_devices = [
      {
        name    = "eth0"
        bridge  = "vmbr0"
        vlan_id = 1
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

    enable_firewall = false
    firewall_rules  = []
    tags            = ["dev", "container"]
  }
]

## Common Tags
tags = {
  Environment = "dev"
  ManagedBy   = "Terraform"
  Owner       = "DevOps"
  Purpose     = "Testing"
}
