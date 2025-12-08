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

  # Temporarily disabled to allow storage migration (dev-zfs uses local-zfs instead of local)
  # Re-enable after successful migration if needed
  # lifecycle {
  #   prevent_destroy = true
  # }
}

# Create cloud-init configuration (only if vendor data is provided)
resource "proxmox_virtual_environment_file" "vendor_data" {
  count = var.cloud_init_vendor_data != null ? 1 : 0

  node_name    = var.node_name
  datastore_id = var.storage_snippets  # Use snippets storage (must be 'local' or similar dir-based)
  content_type = "snippets"

  source_raw {
    file_name = "${var.vm_name}-vendor-data.yaml"
    data      = base64encode(var.cloud_init_vendor_data)
  }

  # Temporarily disabled to allow storage migration (dev-zfs uses local-zfs instead of local)
  # Re-enable after successful migration if needed
  # lifecycle {
  #   prevent_destroy = true
  # }
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
    datastore_id        = var.storage_local  # Where cloud-init ISO is stored (must support 'images' content type)
    interface           = "ide2"
    type                = "nocloud"
    vendor_data_file_id = var.cloud_init_vendor_data != null ? "${var.storage_snippets}:snippets/${var.vm_name}-vendor-data.yaml" : null  # Vendor-data file is stored in snippets storage

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  tags = concat([var.vm_name, "template"], var.tags)
}
