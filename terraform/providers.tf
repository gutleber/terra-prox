# providers.tf - Define all Terraform and provider configuration

terraform {
  required_version = ">=1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">=0.53.1"
    }
  }

  # Uncomment for remote state management
  # backend "s3" {
  #   bucket         = "terraform-state"
  #   key            = "proxmox/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "proxmox" {
  endpoint  = var.pve_api_url
  api_token = "${var.pve_token_id}=${var.pve_token_secret}"
  insecure  = var.pve_insecure

  ssh {
    agent       = true
    username    = var.pve_user
    private_key = var.pve_ssh_key_private
  }
}
