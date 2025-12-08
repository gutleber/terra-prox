# variables.tf - Global variables for Proxmox infrastructure

## Environment & Common Variables
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
  default     = "proxmox"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Project   = "Proxmox"
  }
}

## Provider Authentication Variables
variable "pve_api_url" {
  description = "Proxmox API Endpoint, e.g. 'https://pve.example.com/api2/json'"
  type        = string
  sensitive   = true
  validation {
    condition     = can(regex("(?i)^https?://.*/api2/json$", var.pve_api_url))
    error_message = "Proxmox API Endpoint Invalid. Check URL - Scheme and Path required."
  }
}

variable "pve_token_id" {
  description = "Proxmox API Token Name (format: user@realm!token_name)"
  type        = string
  sensitive   = true
}

variable "pve_token_secret" {
  description = "Proxmox API Token Secret Value"
  type        = string
  sensitive   = true
}

variable "pve_user" {
  description = "Proxmox username for SSH connection"
  type        = string
  sensitive   = true
}

variable "pve_ssh_key_private" {
  description = "Path to private SSH key for Proxmox"
  type        = string
  sensitive   = true
  default     = null
}

variable "pve_insecure" {
  description = "Disable SSL certificate verification"
  type        = bool
  default     = false
}

## Proxmox Infrastructure Variables
variable "node" {
  description = "Name of Proxmox node, e.g. 'pve'"
  type        = string
}

variable "datacenter" {
  description = "Proxmox datacenter identifier"
  type        = string
  default     = "local"
}

variable "storage_local" {
  description = "Storage datastore ID for ISOs and backups. Common values: 'local' (dir), 'files' (dir), 'local-zfs' (ZFS)"
  type        = string
  default     = "local"
}

variable "storage_snippets" {
  description = "Storage datastore ID for cloud-init snippets. Must support 'snippets' content type. Common values: 'local' (dir)"
  type        = string
  default     = "local"
}

variable "storage_vm_disk" {
  description = "Storage datastore ID for VM disks. Common values: 'local-lvm' (LVM), 'local-zfs' (ZFS), 'ceph-pool' (Ceph)"
  type        = string
  default     = "local-lvm"
}

variable "bridge_interface" {
  description = "Network bridge interface name"
  type        = string
  default     = "vmbr0"
}

variable "vlan_id" {
  description = "VLAN ID for network isolation (null = no VLAN tag, number = VLAN tag ID)"
  default     = null
}

## Storage & Disk Configuration Variables
variable "disk_cache" {
  description = "Disk cache mode: 'writeback' (default, faster), 'writethrough' (safer), 'unsafe' (fastest)"
  type        = string
  default     = "writeback"
  validation {
    condition     = contains(["writeback", "writethrough", "unsafe"], var.disk_cache)
    error_message = "Disk cache must be 'writeback', 'writethrough', or 'unsafe'."
  }
}

variable "disk_discard" {
  description = "Enable TRIM/DISCARD: 'on', 'off', 'ignore'"
  type        = string
  default     = "on"
  validation {
    condition     = contains(["on", "off", "ignore"], var.disk_discard)
    error_message = "Disk discard must be 'on', 'off', or 'ignore'."
  }
}

variable "disk_format" {
  description = "Disk image format: 'raw' (recommended for performance), 'qcow2', 'vmdk'"
  type        = string
  default     = "raw"
  validation {
    condition     = contains(["raw", "qcow2", "vmdk"], var.disk_format)
    error_message = "Disk format must be 'raw', 'qcow2', or 'vmdk'."
  }
}

variable "disk_ssd" {
  description = "Optimize for SSD storage (enables TRIM)"
  type        = bool
  default     = true
}

## VM Template Defaults
variable "default_bios" {
  description = "Default BIOS type for templates: 'seabios' (x86/compatibility), 'ovmf' (UEFI/modern)"
  type        = string
  default     = "seabios"
  validation {
    condition     = contains(["seabios", "ovmf"], var.default_bios)
    error_message = "BIOS must be 'seabios' or 'ovmf'."
  }
}

variable "default_machine_type" {
  description = "Default machine type for templates: 'q35' (modern), 'i440fx' (legacy)"
  type        = string
  default     = "q35"
  validation {
    condition     = contains(["q35", "i440fx"], var.default_machine_type)
    error_message = "Machine type must be 'q35' or 'i440fx'."
  }
}

## LXC Configuration Variables
variable "lxc_template_name" {
  description = "Name of LXC template to use"
  type        = string
  default     = "debian-12-standard"
}

variable "lxc_storage" {
  description = "Storage for LXC containers"
  type        = string
  default     = "local-lvm"
}

## VM Templates Configuration
variable "templates" {
  description = "Map of VM template configurations"
  type = map(object({
    vm_id                    = number
    image_url                = string
    image_filename           = string
    image_checksum           = string
    image_checksum_algorithm = optional(string, "sha256")
    bios                     = optional(string, "seabios")
    machine_type             = optional(string, "q35")
    cores                    = optional(number, 2)
    memory                   = optional(number, 2048)
    disk_size                = optional(number, 20)
    cloud_init_vendor_data   = optional(string)
  }))
  default = {}
}

## VMs Configuration
variable "vm_configs" {
  description = "List of VM configurations to create"
  type = list(object({
    name              = string
    template          = string # Template key from templates map
    vm_id             = number
    cores             = optional(number, 2)
    memory            = optional(number, 2048)
    disk_size         = optional(number, 20)
    autostart         = optional(bool, false)
    enable_cloud_init = optional(bool, true)
    cloud_init_user   = optional(string, "debian")
    ssh_public_keys   = optional(list(string), [])

    # Network configuration
    network_devices = optional(list(object({
      bridge  = optional(string, "vmbr0")
      vlan_id = optional(number, null)  # null = no VLAN tag (use bridge directly), number = VLAN tag ID
    })), [{ bridge = "vmbr0", vlan_id = null }])

    ip_configs = optional(list(object({
      ipv4_address = optional(string, "dhcp")
      ipv4_gateway = optional(string)
      ipv6_address = optional(string)
      ipv6_gateway = optional(string)
    })), [])

    # Storage configuration
    additional_disks = optional(list(object({
      datastore_id = optional(string, "local-lvm")
      interface    = string
      size         = number
      file_format  = optional(string, "raw")
      cache        = optional(string, "writeback")
      ssd          = optional(bool, true)
      discard      = optional(string, "on")
    })), [])

    # Operating system and hardware configuration
    os_type                = optional(string, "l26")                  # Linux kernel
    memory_ballooning      = optional(bool, true)                     # Enable memory ballooning (50% floating)
    startup_order          = optional(number)                         # VM startup order (null = no ordering)
    startup_up_delay       = optional(number, 10)                     # Delay before starting next VM
    startup_down_delay     = optional(number, 10)                     # Delay during shutdown
    enable_lvm_auto_resize = optional(bool, true)                     # Auto-expand LVM on boot
    lvm_root_path          = optional(string, "/dev/mapper/pve-root") # Path to LVM root (e.g., /dev/mapper/vg0-root)

    # Firewall configuration
    enable_firewall    = optional(bool, false)
    firewall_log_level = optional(string, "info") # info, nolog, alert, audit
    firewall_rules = optional(list(object({
      type    = optional(string) # "in" or "out"
      action  = optional(string) # "ACCEPT", "DROP", "REJECT"
      comment = optional(string)
      source  = optional(string)
      dest    = optional(string)
      proto   = optional(string)
      dport   = optional(string)
      sport   = optional(string)
      iface   = optional(string)
      log     = optional(string)
      enabled = optional(bool, true)
    })), [])

    # Tags
    tags = optional(list(string), [])
  }))
  default = []
}

## LXC Containers Configuration
variable "lxc_configs" {
  description = "List of LXC container configurations to create"
  type = list(object({
    name             = string
    container_id     = number
    template_file_id = string # Required: LXC template file ID (e.g., "local:vztmpl/debian-12.tar.xz")
    os_type          = optional(string, "debian")
    storage          = optional(string, "local-lvm")
    disk_size        = optional(number, 10)
    volume_size      = optional(number, 10)
    cores            = optional(number, 1)
    cpu_units        = optional(number, 1024)
    memory           = optional(number, 512)
    memory_swap      = optional(number, 512)
    autostart        = optional(bool, false)
    unprivileged     = optional(bool, true)
    startup_order    = optional(number, 0)
    startup_delay    = optional(number, 0)
    shutdown_delay   = optional(number, 0)

    # Network configuration
    network_devices = optional(list(object({
      name    = optional(string, "eth0")
      bridge  = optional(string, "vmbr0")
      vlan_id = optional(number, null)  # null = no VLAN tag (use bridge directly), number = VLAN tag ID
    })), [{ name = "eth0", bridge = "vmbr0", vlan_id = null }])

    # IP configuration
    ip_configs = optional(list(object({
      ipv4_address = optional(string)
      ipv4_gateway = optional(string)
      ipv6_address = optional(string)
      ipv6_gateway = optional(string)
    })), [{ ipv4_address = "dhcp" }])

    dns_servers = optional(list(string), ["8.8.8.8", "8.8.4.4"])

    # SSH and user configuration
    ssh_public_keys = optional(list(string), [])
    root_password   = optional(string)

    # Firewall configuration
    enable_firewall    = optional(bool, false)
    firewall_log_level = optional(string, "info")
    firewall_rules = optional(list(object({
      type    = optional(string) # "in" or "out"
      action  = optional(string) # "ACCEPT", "DROP", "REJECT"
      comment = optional(string)
      source  = optional(string)
      dest    = optional(string)
      proto   = optional(string)
      dport   = optional(string)
      sport   = optional(string)
      iface   = optional(string)
      log     = optional(string)
      enabled = optional(bool, true)
    })), [])

    # Tags
    tags = optional(list(string), [])
  }))
  default = []
}

## Default Storage Configuration (used if not specified in templates)
variable "storage_default_local" {
  description = "Default local storage datastore for ISOs and snippets"
  type        = string
  default     = "local"
}

variable "storage_default_lvm" {
  description = "Default LVM storage datastore for VM disks"
  type        = string
  default     = "local-lvm"
}
