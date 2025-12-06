# modules/lxc/outputs.tf - Outputs for LXC module

output "container_id" {
  description = "Container ID"
  value       = proxmox_virtual_environment_container.container.id
}

output "container_name" {
  description = "Container hostname"
  value       = proxmox_virtual_environment_container.container.hostname
}

output "node_name" {
  description = "Proxmox node name"
  value       = proxmox_virtual_environment_container.container.node_name
}

output "status" {
  description = "Container status"
  value       = proxmox_virtual_environment_container.container.status
}

output "ip_address" {
  description = "Primary IP address of container"
  value       = try(proxmox_virtual_environment_container.container.network_interface[0].ip_address, null)
}
