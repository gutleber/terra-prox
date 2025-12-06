# modules/template/variables.tf - Variables for template module

variable "node_name" {
  description = "Name of Proxmox node"
  type        = string
}

variable "vm_id" {
  description = "VM ID for template"
  type        = number
}

variable "vm_name" {
  description = "VM template name"
  type        = string
}

variable "bios" {
  description = "BIOS type (seabios or ovmf)"
  type        = string
  default     = "seabios"
}

variable "machine_type" {
  description = "Machine type (q35, i440fx)"
  type        = string
  default     = "q35"
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

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 20
}

variable "storage_local" {
  description = "Storage datastore for ISOs, backups, and snippets. Common values: 'local' (dir), 'local-zfs' (ZFS), 'pbs' (PBS)"
  type        = string
  default     = "local"
}

variable "storage_vm_disk" {
  description = "Storage datastore for VM disks. Common values: 'local-lvm' (LVM), 'local-zfs' (ZFS), 'ceph-pool' (Ceph)"
  type        = string
  default     = "local-lvm"
}

variable "bridge_interface" {
  description = "Network bridge interface"
  type        = string
  default     = "vmbr0"
}

variable "vlan_id" {
  description = "VLAN ID"
  type        = number
  default     = 1
}

variable "image_url" {
  description = "Cloud image URL"
  type        = string
}

variable "image_filename" {
  description = "Image filename"
  type        = string
}

variable "image_checksum" {
  description = "Image checksum"
  type        = string
}

variable "image_checksum_algorithm" {
  description = "Checksum algorithm"
  type        = string
  default     = "sha256"
}

variable "cloud_init_vendor_data" {
  description = "Cloud-init vendor data configuration"
  type        = string
  default     = <<-EOF
    #cloud-config
    packages:
      - qemu-guest-agent
      - curl
      - wget
    package_update: true
    power_state:
      mode: reboot
      timeout: 30
  EOF
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = list(string)
  default     = []
}

## Disk Configuration Variables
variable "disk_cache" {
  description = "Disk cache mode: 'writeback' (default), 'writethrough', 'unsafe'"
  type        = string
  default     = "writeback"
}

variable "disk_discard" {
  description = "Enable TRIM/DISCARD: 'on', 'off', 'ignore'"
  type        = string
  default     = "on"
}

variable "disk_format" {
  description = "Disk image format: 'raw' (recommended), 'qcow2', 'vmdk'"
  type        = string
  default     = "raw"
}

variable "disk_ssd" {
  description = "Optimize for SSD storage (enables TRIM)"
  type        = bool
  default     = true
}
