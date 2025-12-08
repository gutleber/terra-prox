# modules/vm/variables.tf - Variables for VM module

variable "node_name" {
  description = "Proxmox node name"
  type        = string
}

variable "vm_id" {
  description = "VM ID"
  type        = number
}

variable "vm_name" {
  description = "VM name"
  type        = string
}

variable "template_vm_id" {
  description = "Template VM ID to clone from"
  type        = number
}

variable "storage_vm_disk" {
  description = "Storage location for VM disks (e.g., 'local-lvm', 'local-zfs')"
  type        = string
  default     = "local-lvm"
}

variable "os_type" {
  description = "Operating system type (l26=Linux, w=Windows)"
  type        = string
  default     = "l26"
  validation {
    condition     = contains(["l26", "w"], var.os_type)
    error_message = "OS type must be 'l26' (Linux) or 'w' (Windows)."
  }
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 2048
}

variable "memory_ballooning" {
  description = "Enable memory ballooning (floating memory set to 50% of dedicated)"
  type        = bool
  default     = true
}

variable "autostart" {
  description = "Automatically start VM on boot"
  type        = bool
  default     = false
}

variable "startup_order" {
  description = "Startup order for coordinated VM startup (null = no startup ordering)"
  type        = number
  default     = null
}

variable "startup_up_delay" {
  description = "Delay in seconds before starting the next VM during startup sequence"
  type        = number
  default     = 10
}

variable "startup_down_delay" {
  description = "Delay in seconds during shutdown sequence"
  type        = number
  default     = 10
}

variable "enable_lvm_auto_resize" {
  description = "Enable automatic LVM root filesystem expansion during first boot (critical for resized clones)"
  type        = bool
  default     = true
}

variable "lvm_root_path" {
  description = "Path to LVM root logical volume for auto-resize (e.g., /dev/mapper/pve-root or /dev/mapper/vg0-root)"
  type        = string
  default     = "/dev/mapper/pve-root"
}

variable "enable_cloud_init" {
  description = "Enable cloud-init configuration"
  type        = bool
  default     = true
}

variable "cloud_init_user" {
  description = "Cloud-init user account name"
  type        = string
  default     = "debian"
}

variable "storage_local" {
  description = "Storage datastore ID for ISOs. Must support 'images' content type (e.g., 'files')"
  type        = string
  default     = "local"
}

variable "storage_snippets" {
  description = "Storage datastore ID where cloud-init snippets are stored. Must support 'snippets' content type (e.g., 'local')"
  type        = string
  default     = "local"
}

variable "ssh_public_keys" {
  description = "SSH public keys to add to cloud-init"
  type        = list(string)
  default     = []
}

variable "ip_configs" {
  description = "IP configuration for cloud-init"
  type = list(object({
    ipv4_address  = string
    ipv4_gateway  = optional(string)
    ipv6_address  = optional(string)
    ipv6_gateway  = optional(string)
  }))
  default = []
}

variable "network_devices" {
  description = "Network device configuration"
  type = list(object({
    bridge  = string
    vlan_id = optional(number)
  }))
  default = [
    {
      bridge  = "vmbr0"
      vlan_id = 1
    }
  ]
}

variable "additional_disks" {
  description = "Additional disks to attach to VM"
  type = list(object({
    datastore_id = string
    interface    = string
    size         = number
    file_format  = string
    cache        = optional(string, "writeback")
    ssd          = optional(bool, true)
    discard      = optional(string, "on")
  }))
  default = []
}

variable "enable_firewall" {
  description = "Enable firewall rules for VM (also enables firewall enforcement on network interfaces)"
  type        = bool
  default     = false
}

variable "firewall_log_level" {
  description = "Firewall log level (info, nolog, alert, or audit)"
  type        = string
  default     = "info"
  validation {
    condition     = contains(["info", "nolog", "alert", "audit"], var.firewall_log_level)
    error_message = "Firewall log level must be 'info', 'nolog', 'alert', or 'audit'."
  }
}

variable "firewall_rules" {
  description = "Firewall rules for VM"
  type = list(object({
    type       = optional(string)     # "in" or "out"
    action     = optional(string)     # "ACCEPT", "DROP", "REJECT"
    comment    = optional(string)
    source     = optional(string)
    dest       = optional(string)
    proto      = optional(string)
    dport      = optional(string)
    sport      = optional(string)
    iface      = optional(string)
    log        = optional(string)
    enabled    = optional(bool, true)
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to VM"
  type        = list(string)
  default     = []
}
