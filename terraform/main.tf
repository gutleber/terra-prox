# main.tf - Root orchestration file for Proxmox infrastructure

# Create VM templates using for_each
module "template" {
  for_each = var.templates

  source = "./modules/template"

  providers = {
    proxmox = proxmox
  }

  node_name                = var.node
  vm_id                    = each.value.vm_id
  vm_name                  = "${var.project_name}-${each.key}-template"
  bios                     = each.value.bios
  machine_type             = each.value.machine_type
  cores                    = each.value.cores
  memory                   = each.value.memory
  disk_size                = each.value.disk_size
  storage_local            = var.storage_local
  storage_snippets         = var.storage_snippets
  storage_vm_disk          = var.storage_vm_disk
  bridge_interface         = var.bridge_interface
  vlan_id                  = var.vlan_id
  disk_cache               = var.disk_cache
  disk_discard             = var.disk_discard
  disk_format              = var.disk_format
  disk_ssd                 = var.disk_ssd
  image_url                = each.value.image_url
  image_filename           = each.value.image_filename
  image_checksum           = each.value.image_checksum
  image_checksum_algorithm = each.value.image_checksum_algorithm
  cloud_init_vendor_data   = each.value.cloud_init_vendor_data != null ? each.value.cloud_init_vendor_data : null

  tags = concat(values(var.tags), ["environment-${var.environment}", "template-${each.key}"])
}

# Create VMs from templates using for_each
module "vm" {
  for_each = { for vm in var.vm_configs : vm.name => vm }

  source = "./modules/vm"

  providers = {
    proxmox = proxmox
  }

  node_name               = var.node
  vm_id                   = each.value.vm_id
  vm_name                 = each.value.name
  template_vm_id          = module.template[each.value.template].vm_id
  storage_local           = var.storage_local
  storage_snippets        = var.storage_snippets
  storage_vm_disk         = var.storage_vm_disk
  cores                   = each.value.cores
  memory                  = each.value.memory
  memory_ballooning       = each.value.memory_ballooning != null ? each.value.memory_ballooning : true
  autostart               = each.value.autostart
  enable_cloud_init       = each.value.enable_cloud_init
  cloud_init_user         = each.value.cloud_init_user
  ssh_public_keys         = each.value.ssh_public_keys

  os_type                = each.value.os_type != null ? each.value.os_type : "l26"
  startup_order          = each.value.startup_order
  startup_up_delay       = each.value.startup_up_delay != null ? each.value.startup_up_delay : 10
  startup_down_delay     = each.value.startup_down_delay != null ? each.value.startup_down_delay : 10
  enable_lvm_auto_resize = each.value.enable_lvm_auto_resize != null ? each.value.enable_lvm_auto_resize : true
  lvm_root_path          = each.value.lvm_root_path != null ? each.value.lvm_root_path : "/dev/mapper/pve-root"

  network_devices  = each.value.network_devices
  ip_configs       = each.value.ip_configs
  additional_disks = each.value.additional_disks

  enable_firewall    = each.value.enable_firewall
  firewall_log_level = each.value.firewall_log_level != null ? each.value.firewall_log_level : "info"
  firewall_rules     = each.value.firewall_rules

  tags = concat(
    values(var.tags),
    [
      "environment-${var.environment}",
      "type-vm"
    ],
    each.value.tags
  )

  depends_on = [module.template]
}

# Create LXC containers using for_each
module "lxc" {
  for_each = { for container in var.lxc_configs : container.name => container }

  source = "./modules/lxc"

  providers = {
    proxmox = proxmox
  }

  node_name        = var.node
  container_id     = each.value.container_id
  container_name   = each.value.name
  template_file_id = each.value.template_file_id
  os_type          = each.value.os_type
  storage          = each.value.storage
  disk_size        = each.value.disk_size
  volume_size      = each.value.volume_size
  cores            = each.value.cores
  cpu_units        = each.value.cpu_units
  memory           = each.value.memory
  memory_swap      = each.value.memory_swap
  autostart        = each.value.autostart
  unprivileged     = each.value.unprivileged
  startup_order    = each.value.startup_order
  startup_delay    = each.value.startup_delay
  shutdown_delay   = each.value.shutdown_delay

  network_devices = each.value.network_devices
  ip_configs      = each.value.ip_configs
  dns_servers     = each.value.dns_servers
  ssh_public_keys = each.value.ssh_public_keys
  root_password   = each.value.root_password

  enable_firewall    = each.value.enable_firewall
  firewall_log_level = each.value.firewall_log_level != null ? each.value.firewall_log_level : "info"
  firewall_rules     = each.value.firewall_rules

  tags = concat(
    values(var.tags),
    [
      "environment-${var.environment}",
      "type-lxc"
    ],
    each.value.tags
  )
}
