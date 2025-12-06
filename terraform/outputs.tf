# outputs.tf - Output values for reference and display

## Templates Outputs
output "templates_created" {
  description = "Information about created VM templates"
  value = {
    for name, template in module.template :
    name => {
      vm_id       = template.vm_id
      vm_name     = template.vm_name
      node        = template.node_name
      template_id = template.template_id
      image_id    = template.image_id
    }
  }
}

## VMs Outputs
output "vms_created" {
  description = "Detailed information about all created VMs"
  value = {
    for name, vm in module.vm :
    name => {
      vm_id    = vm.vm_id
      vm_name  = vm.vm_name
      node     = vm.node_name
      status   = vm.status
      ip_address = vm.ip_address
    }
  }
}

output "vms_summary" {
  description = "Summary of VMs (name -> IP address)"
  value = {
    for name, vm in module.vm :
    name => vm.ip_address != null ? vm.ip_address : "Not assigned"
  }
}

## LXC Containers Outputs
output "lxc_containers_created" {
  description = "Detailed information about all created LXC containers"
  value = {
    for name, container in module.lxc :
    name => {
      container_id   = container.container_id
      container_name = container.container_name
      node           = container.node_name
      status         = container.status
      ip_address     = container.ip_address
    }
  }
}

output "lxc_containers_summary" {
  description = "Summary of LXC containers (name -> IP address)"
  value = {
    for name, container in module.lxc :
    name => container.ip_address != null ? container.ip_address : "Not assigned"
  }
}

## Combined Resources Summary
output "infrastructure_summary" {
  description = "Complete infrastructure summary"
  value = {
    environment  = var.environment
    node         = var.node
    templates_count = length(module.template)
    vms_count       = length(module.vm)
    lxc_count       = length(module.lxc)
    total_resources = length(module.template) + length(module.vm) + length(module.lxc)
  }
}

## Proxmox Node Information
output "proxmox_configuration" {
  description = "Proxmox infrastructure configuration"
  value = {
    node             = var.node
    datacenter       = var.datacenter
    storage_local    = var.storage_local
    storage_vm_disk  = var.storage_vm_disk
    bridge_interface = var.bridge_interface
    default_vlan     = var.vlan_id
    environment      = var.environment
  }
}

## Resource IDs for Further Reference
output "template_ids" {
  description = "VM template IDs for reference"
  value = {
    for name, template in module.template :
    name => template.vm_id
  }
}

output "vm_ids" {
  description = "VM IDs for reference"
  value = {
    for name, vm in module.vm :
    name => vm.vm_id
  }
}

output "lxc_ids" {
  description = "LXC container IDs for reference"
  value = {
    for name, container in module.lxc :
    name => container.container_id
  }
}
