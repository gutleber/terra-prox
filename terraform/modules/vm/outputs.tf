# modules/vm/outputs.tf - Outputs for VM module

output "vm_id" {
  description = "VM ID"
  value       = proxmox_virtual_environment_vm.vm.id
}

output "vm_name" {
  description = "VM name"
  value       = proxmox_virtual_environment_vm.vm.name
}

output "node_name" {
  description = "Proxmox node name"
  value       = proxmox_virtual_environment_vm.vm.node_name
}

output "ip_address" {
  description = "Primary IP address of VM (if available)"
  value       = try(proxmox_virtual_environment_vm.vm.initialization[0].ip_config[0].ipv4[0].address, null)
}
