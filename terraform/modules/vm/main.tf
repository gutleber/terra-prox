# modules/vm/main.tf - VM module for Proxmox (clone from template)

resource "proxmox_virtual_environment_vm" "vm" {
  node_name = var.node_name
  vm_id     = var.vm_id
  name      = var.vm_name

  # Clone from template
  clone {
    vm_id = var.template_vm_id
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

  # Network configuration
  dynamic "network_device" {
    for_each = var.network_devices
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
      interface = "ide2"
      type      = "nocloud"

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
        keys    = var.ssh_public_keys
        username = var.cloud_init_user
      }

      # LVM auto-resize: Automatically expand root filesystem to use full disk size
      # Critical for VMs where disk size was increased during cloning
      dynamic "custom" {
        for_each = var.enable_lvm_auto_resize ? [1] : []
        content {
          type = "vendor-data"
          data = base64encode(<<-EOT
            #cloud-config
            runcmd:
              - [ sh, -c, "growpart /dev/vda 3" ]
              - [ sh, -c, "pvresize /dev/vda3" ]
              - [ sh, -c, "lvextend -l +100%FREE ${var.lvm_root_path}" ]
              - [ sh, -c, "resize2fs ${var.lvm_root_path}" ]
          EOT
          )
        }
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
      initialization  # Ignore cloud-init changes after first deployment
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
      action      = rule.value.action
      direction   = rule.value.direction
      interface   = rule.value.interface
      protocol    = rule.value.protocol
      port        = rule.value.port
      source      = rule.value.source
      destination = rule.value.destination
      comment     = rule.value.comment
    }
  }
}
