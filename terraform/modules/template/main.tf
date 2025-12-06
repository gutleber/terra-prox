# modules/template/main.tf - VM Template module for Proxmox

# Download cloud image from URL
resource "proxmox_virtual_environment_download_file" "image" {
  node_name          = var.node_name
  content_type       = "iso"
  datastore_id       = var.storage_local
  file_name          = var.image_filename
  url                = var.image_url
  checksum           = var.image_checksum
  checksum_algorithm = var.image_checksum_algorithm
  overwrite          = false

  lifecycle {
    prevent_destroy = true
  }
}

# Create cloud-init configuration
resource "proxmox_virtual_environment_file" "vendor_data" {
  node_name    = var.node_name
  datastore_id = var.storage_local
  content_type = "snippets"

  source_raw {
    file_name = "${var.vm_name}-vendor-data.yaml"
    data      = var.cloud_init_vendor_data
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Create VM template
resource "proxmox_virtual_environment_vm" "template" {
  depends_on = [proxmox_virtual_environment_download_file.image]

  node_name = var.node_name
  vm_id     = var.vm_id
  name      = var.vm_name
  bios      = var.bios
  machine   = var.machine_type
  started   = false  # Don't boot the template
  template  = true   # Mark as template

  agent {
    enabled = true
  }

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory
    floating  = var.memory
  }

  # Create EFI disk when using OVMF
  dynamic "efi_disk" {
    for_each = (var.bios == "ovmf" ? [1] : [])
    content {
      datastore_id      = var.storage_vm_disk
      file_format       = "raw"
      type              = "4m"
      pre_enrolled_keys = true
    }
  }

  # Main disk
  disk {
    file_id      = proxmox_virtual_environment_download_file.image.id
    datastore_id = var.storage_vm_disk
    interface    = "scsi0"
    size         = var.disk_size
    file_format  = var.disk_format
    cache        = var.disk_cache
    iothread     = false
    ssd          = var.disk_ssd
    discard      = var.disk_discard
  }

  # Network configuration
  network_device {
    bridge  = var.bridge_interface
    vlan_id = var.vlan_id
  }

  # Cloud-init configuration
  initialization {
    interface           = "ide2"
    type                = "nocloud"
    vendor_data_file_id = "${var.storage_local}:snippets/${var.vm_name}-vendor-data.yaml"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  tags = concat([var.vm_name, "template"], var.tags)
}
