# modules/lxc/main.tf - LXC Container module for Proxmox

resource "proxmox_virtual_environment_container" "container" {
  node_name = var.node_name
  vm_id     = var.container_id
  hostname  = var.container_name

  # Operating system configuration
  ostype = var.os_type
  osversion = var.os_version

  # Storage and resource allocation
  root_filesystem {
    storage      = var.storage
    disk_size    = var.disk_size
    volume_size  = var.volume_size
  }

  cpu {
    cores = var.cores
    units = var.cpu_units
  }

  memory {
    dedicated = var.memory
    swap      = var.memory_swap
  }

  # Network configuration
  dynamic "network_device" {
    for_each = var.network_devices
    content {
      name     = network_device.value.name
      bridge   = network_device.value.bridge
      vlan_id  = network_device.value.vlan_id
      firewall = var.enable_firewall
    }
  }

  # DNS configuration
  dns {
    servers = var.dns_servers
  }

  # Root user password (optional, use SSH keys instead)
  dynamic "password" {
    for_each = var.root_password != null ? [1] : []
    content {
      encrypted = false
      value     = var.root_password
    }
  }

  # SSH public keys
  dynamic "ssh_public_keys" {
    for_each = length(var.ssh_public_keys) > 0 ? [1] : []
    content {
      keys = var.ssh_public_keys
    }
  }

  # Startup options (only if startup_order is specified)
  dynamic "startup" {
    for_each = var.startup_order > 0 ? [1] : []
    content {
      order      = var.startup_order
      up_delay   = var.startup_delay
      down_delay = var.shutdown_delay
    }
  }

  started = var.autostart
  unprivileged = var.unprivileged

  tags = concat([var.container_name, "lxc"], var.tags)

  lifecycle {
    ignore_changes = [
      password  # Don't manage password changes after creation
    ]
  }
}

# Firewall options - Security-first configuration (default deny inbound, allow outbound)
resource "proxmox_virtual_environment_firewall_options" "container" {
  count = var.enable_firewall ? 1 : 0

  node_name    = var.node_name
  container_id = proxmox_virtual_environment_container.container.vm_id

  dhcp          = true
  enabled       = true
  ipfilter      = false
  log_level_in  = var.firewall_log_level
  input_policy  = "DROP"
  output_policy = "ACCEPT"
}

# Optional: Create firewall rules for container
resource "proxmox_virtual_environment_firewall_rules" "container_rules" {
  count = var.enable_firewall ? 1 : 0

  node_name   = var.node_name
  container_id = proxmox_virtual_environment_container.container.vm_id

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
