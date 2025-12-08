# modules/vm/main.tf - VM module for Proxmox (clone from template)

# Create vendor-data file for LVM auto-resize (if enabled)
resource "proxmox_virtual_environment_file" "vendor_data" {
  count = var.enable_lvm_auto_resize ? 1 : 0

  content_type = "snippets"
  datastore_id = var.storage_snippets  # Use snippets storage (must be 'local' or similar dir-based)
  node_name    = var.node_name

  source_raw {
    data = <<-EOT
      #cloud-config
      runcmd:
        - [ sh, -c, "growpart /dev/vda 3" ]
        - [ sh, -c, "pvresize /dev/vda3" ]
        - [ sh, -c, "lvextend -l +100%FREE ${var.lvm_root_path}" ]
        - [ sh, -c, "resize2fs ${var.lvm_root_path}" ]
    EOT

    file_name = "vendor-${var.vm_name}.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  node_name = var.node_name
  vm_id     = var.vm_id
  name      = var.vm_name

  # Clone from template
  clone {
    vm_id        = var.template_vm_id
    datastore_id = var.storage_vm_disk
    full         = true # Full clone (independent copy) vs linked clone
  }

  # Operating system configuration
  operating_system {
    type = var.os_type
  }

  # Override template settings as needed
  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory
    floating  = var.memory_ballooning ? floor(var.memory / 2) : var.memory
  }

  # Serial device for debugging boot issues
  serial_device {}

  # Optional: Add additional disks
  dynamic "disk" {
    for_each = var.additional_disks
    content {
      datastore_id = disk.value.datastore_id
      interface    = disk.value.interface
      size         = disk.value.size
      file_format  = disk.value.file_format
      cache        = disk.value.cache
      ssd          = disk.value.ssd
      discard      = disk.value.discard
    }
  }

  # Network configuration - two branches: with or without VLAN tagging
  # Use dedicated VLAN interface (e.g., vlan6) when vlan_id is null
  dynamic "network_device" {
    for_each = [for dev in var.network_devices : dev if dev.vlan_id == null]
    content {
      bridge   = network_device.value.bridge
      firewall = var.enable_firewall
    }
  }

  # Use bridge with VLAN tagging (e.g., vmbr0,tag=6) when vlan_id is provided
  dynamic "network_device" {
    for_each = [for dev in var.network_devices : dev if dev.vlan_id != null]
    content {
      bridge   = network_device.value.bridge
      vlan_id  = network_device.value.vlan_id
      firewall = var.enable_firewall
    }
  }

  # Cloud-init for VM-specific customization
  dynamic "initialization" {
    for_each = var.enable_cloud_init ? [1] : []
    content {
      datastore_id = var.storage_local  # Where cloud-init ISO is stored (must support 'images' content type)
      interface    = "ide2"
      type         = "nocloud"

      # Reference vendor-data file for LVM auto-resize (if enabled)
      vendor_data_file_id = var.enable_lvm_auto_resize ? proxmox_virtual_environment_file.vendor_data[0].id : null

      dynamic "ip_config" {
        for_each = var.ip_configs
        content {
          ipv4 {
            address = ip_config.value.ipv4_address
            gateway = ip_config.value.ipv4_gateway
          }
          ipv6 {
            address = ip_config.value.ipv6_address
            gateway = ip_config.value.ipv6_gateway
          }
        }
      }

      user_account {
        keys     = var.ssh_public_keys
        username = var.cloud_init_user
      }
    }
  }

  # Startup configuration for coordinated VM startup/shutdown
  dynamic "startup" {
    for_each = var.startup_order != null ? [1] : []
    content {
      order      = var.startup_order
      up_delay   = var.startup_up_delay
      down_delay = var.startup_down_delay
    }
  }

  started = var.autostart

  tags = concat([var.vm_name, "vm"], var.tags)

  lifecycle {
    ignore_changes = [
      initialization # Ignore cloud-init changes after first deployment
    ]
  }
}

# Firewall options: Security policy (default deny inbound, allow outbound)
# This follows security best practices from module-machine-main
resource "proxmox_virtual_environment_firewall_options" "vm" {
  count = var.enable_firewall ? 1 : 0

  node_name = var.node_name
  vm_id     = proxmox_virtual_environment_vm.vm.vm_id

  dhcp         = true
  enabled      = true
  ipfilter     = false
  log_level_in = var.firewall_log_level
  macfilter    = false
  ndp          = true
  radv         = true

  # Security-first policy: Default deny inbound, allow outbound
  input_policy  = "DROP"
  output_policy = "ACCEPT"
}

# Optional: Create a firewall rule group for the VM
resource "proxmox_virtual_environment_firewall_rules" "vm_rules" {
  count = var.enable_firewall ? 1 : 0

  depends_on = [proxmox_virtual_environment_firewall_options.vm]

  node_name = var.node_name
  vm_id     = proxmox_virtual_environment_vm.vm.vm_id

  dynamic "rule" {
    for_each = var.firewall_rules
    content {
      type    = rule.value.type
      action  = rule.value.action
      comment = rule.value.comment
      source  = rule.value.source
      dest    = rule.value.dest
      proto   = rule.value.proto
      dport   = rule.value.dport
      sport   = rule.value.sport
      iface   = rule.value.iface
      log     = rule.value.log
      enabled = rule.value.enabled
    }
  }
}
