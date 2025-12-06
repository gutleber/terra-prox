# modules/template/outputs.tf - Outputs for template module

output "vm_id" {
  description = "VM template ID"
  value       = proxmox_virtual_environment_vm.template.id
}

output "vm_name" {
  description = "VM template name"
  value       = proxmox_virtual_environment_vm.template.name
}

output "node_name" {
  description = "Proxmox node name"
  value       = proxmox_virtual_environment_vm.template.node_name
}

output "template_id" {
  description = "Full template reference for cloning"
  value       = "${proxmox_virtual_environment_vm.template.node_name}/${proxmox_virtual_environment_vm.template.name}"
}

output "image_id" {
  description = "Downloaded image file ID"
  value       = proxmox_virtual_environment_download_file.image.id
}
