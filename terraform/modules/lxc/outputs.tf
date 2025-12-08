# modules/lxc/outputs.tf - Outputs for LXC module

output "container_id" {
  description = "Container ID"
  value       = proxmox_virtual_environment_container.container.vm_id
}

output "container_name" {
  description = "Container hostname"
  value       = var.container_name
}

output "node_name" {
  description = "Proxmox node name"
  value       = proxmox_virtual_environment_container.container.node_name
}

output "ip_address" {
  description = "Primary IP address of container (from initialization config)"
  value       = try(var.ip_configs[0].ipv4_address, null)
}
