# modules/lxc/variables.tf - Variables for LXC module

variable "node_name" {
  description = "Proxmox node name"
  type        = string
}

variable "container_id" {
  description = "Container ID"
  type        = number
}

variable "container_name" {
  description = "Container hostname"
  type        = string
}

variable "template_file_id" {
  description = "LXC container template file ID (e.g., 'local:vztmpl/debian-12.tar.xz')"
  type        = string
}

variable "os_type" {
  description = "OS type (debian, ubuntu, alma, rocky, alpine, etc.)"
  type        = string
  default     = "debian"
  validation {
    condition     = contains(["debian", "ubuntu", "alma", "rocky", "alpine"], var.os_type)
    error_message = "Invalid OS type."
  }
}

variable "storage" {
  description = "Storage datastore ID for container disks. Common values: 'local-lvm' (LVM), 'local-zfs' (ZFS), 'ceph-pool' (Ceph)"
  type        = string
  default     = "local-lvm"
}

variable "disk_size" {
  description = "Root disk size in GB"
  type        = number
  default     = 10
}

variable "volume_size" {
  description = "Volume size in GB"
  type        = number
  default     = 10
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 1
}

variable "cpu_units" {
  description = "CPU units"
  type        = number
  default     = 1024
}

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 512
}

variable "memory_swap" {
  description = "Swap memory in MB"
  type        = number
  default     = 512
}

variable "network_devices" {
  description = "Network devices configuration"
  type = list(object({
    name    = string
    bridge  = string
    vlan_id = optional(number)
  }))
  default = [
    {
      name   = "eth0"
      bridge = "vmbr0"
      vlan_id = 1
    }
  ]
}

variable "ip_configs" {
  description = "IP configuration for each network interface"
  type = list(object({
    ipv4_address = optional(string)
    ipv4_gateway = optional(string)
    ipv6_address = optional(string)
    ipv6_gateway = optional(string)
  }))
  default = [
    {
      ipv4_address = "dhcp"
      ipv4_gateway = null
    }
  ]
}

variable "dns_servers" {
  description = "DNS servers"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

variable "ssh_public_keys" {
  description = "SSH public keys for root user"
  type        = list(string)
  default     = []
}

variable "root_password" {
  description = "Root user password (not recommended, use SSH keys instead)"
  type        = string
  sensitive   = true
  default     = null
}

variable "autostart" {
  description = "Automatically start container on boot"
  type        = bool
  default     = false
}

variable "unprivileged" {
  description = "Run container in unprivileged mode"
  type        = bool
  default     = true
}

variable "startup_order" {
  description = "Startup order"
  type        = number
  default     = 0
}

variable "startup_delay" {
  description = "Startup delay in seconds"
  type        = number
  default     = 0
}

variable "shutdown_delay" {
  description = "Shutdown delay in seconds"
  type        = number
  default     = 0
}

variable "enable_firewall" {
  description = "Enable firewall rules and network interface enforcement"
  type        = bool
  default     = false
}

variable "firewall_log_level" {
  description = "Firewall log level (info, nolog, alert, audit)"
  type        = string
  default     = "info"
  validation {
    condition     = contains(["info", "nolog", "alert", "audit"], var.firewall_log_level)
    error_message = "Firewall log level must be one of: info, nolog, alert, audit."
  }
}

variable "firewall_rules" {
  description = "Firewall rules"
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
  description = "Tags to apply to container"
  type        = list(string)
  default     = []
}
