# environments/dev/locals.tf - Local values for development environment

locals {
  default_disk_config = {
    datastore_id = var.storage_vm_disk # Inherits from storage_vm_disk variable
    file_format  = var.disk_format     # Inherits from disk_format variable
    cache        = var.disk_cache      # Inherits from disk_cache variable
    ssd          = var.disk_ssd        # Inherits from disk_ssd variable
    discard      = var.disk_discard    # Inherits from disk_discard variable
  }
}
