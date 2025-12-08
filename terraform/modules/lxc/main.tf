# modules/lxc/main.tf - LXC Container module for Proxmox

resource "proxmox_virtual_environment_container" "container" {
  node_name = var.node_name
  vm_id     = var.container_id

  # Operating system configuration (REQUIRED)
  operating_system {
    template_file_id = var.template_file_id  # e.g., "local:vztmpl/ubuntu-22.04.tar.xz"
    type            = var.os_type            # e.g., "ubuntu", "debian", "alpine"
  }

  # Storage and resource allocation
  disk {
    datastore_id = var.storage
    size         = var.disk_size
  }

  cpu {
    cores = var.cores
    units = var.cpu_units
  }

  memory {
    dedicated = var.memory
    swap      = var.memory_swap
  }

  # Network configuration (CORRECT: network_interface, not network_device)
  dynamic "network_interface" {
    for_each = var.network_devices
    content {
      name     = network_interface.value.name
      bridge   = network_interface.value.bridge
      vlan_id  = network_interface.value.vlan_id
      firewall = var.enable_firewall
    }
  }

  # Initialization block contains hostname, DNS, password, and SSH keys
  initialization {
    hostname = var.container_name

    # DNS configuration (moved into initialization) - only create if dns_servers is not empty
    dynamic "dns" {
      for_each = length(var.dns_servers) > 0 ? [1] : []
      content {
        servers = var.dns_servers
      }
    }

    # IP configuration
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

    # User account (contains password and SSH keys - moved into initialization)
    user_account {
      keys     = var.ssh_public_keys
      password = var.root_password
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

  started       = var.autostart
  unprivileged  = var.unprivileged

  tags = concat([var.container_name, "lxc"], var.tags)

  lifecycle {
    ignore_changes = [
      initialization  # Don't manage initialization changes after creation
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
      type        = rule.value.type
      action      = rule.value.action
      comment     = rule.value.comment
      source      = rule.value.source
      dest        = rule.value.dest
      proto       = rule.value.proto
      dport       = rule.value.dport
      sport       = rule.value.sport
      iface       = rule.value.iface
      log         = rule.value.log
      enabled     = rule.value.enabled
    }
  }
}
