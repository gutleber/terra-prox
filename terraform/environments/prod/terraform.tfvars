# environments/prod/terraform.tfvars - Production environment configuration
# Full-scale deployment with VMs and LXC containers

## Environment
environment  = "prod"
project_name = "proxmox-prod"

## Proxmox Configuration
# Update these values according to your Proxmox setup
node             = "prox01"    # Proxmox node name
datacenter       = "local"     # Datacenter ID
storage_local    = "local"     # Storage for ISOs/backups. For ZFS: use "local-zfs"
storage_vm_disk  = "local-lvm" # Storage for VM disks. For ZFS: use "local-zfs"
bridge_interface = "vmbr0"     # Network bridge
vlan_id          = 10          # Production VLAN

## Storage & Disk Configuration
disk_cache   = "writeback" # Disk cache: 'writeback' (fast), 'writethrough' (safe), 'unsafe' (fastest)
disk_discard = "on"        # Enable TRIM/DISCARD for SSDs: 'on', 'off', 'ignore'
disk_format  = "raw"       # Disk format: 'raw' (performance), 'qcow2', 'vmdk'
disk_ssd     = true        # Optimize for SSD storage

## VM Templates - Multiple template options
templates = {
  "ubuntu22-prod" = {
    vm_id                    = 9000
    image_url                = "https://cloud-images.ubuntu.com/releases/jammy/release/ubuntu-22.04-server-cloudimg-amd64.img"
    image_filename           = "ubuntu-22.04-server-cloudimg-amd64.img"
    image_checksum           = "aa4b6d2479555774cdcfc4f39fde4d460a842977e8d20d8c7347813baf6b4777" # Get from: curl -s https://cloud-images.ubuntu.com/releases/jammy/release/SHA256SUMS | grep amd64.img
    image_checksum_algorithm = "sha256"
    bios                     = "seabios"
    machine_type             = "q35"
    cores                    = 4
    memory                   = 4096
    disk_size                = 50
  }

  "debian12-prod" = {
    vm_id                    = 9001
    image_url                = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
    image_filename           = "debian-12-generic-amd64.img"
    image_checksum           = "5da221d8f7434ee86145e78a2c60ca45eb4ef8296535e04f6f333193225792aa8ceee3df6aea2b4ee72d6793f7312308a8b0c6a1c7ed4c7c730fa7bda1bc665f"
    image_checksum_algorithm = "sha512"
    bios                     = "seabios"
    machine_type             = "q35"
    cores                    = 4
    memory                   = 4096
    disk_size                = 50
  }

  "debian12-minimal" = {
    vm_id                    = 9002
    image_url                = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
    image_filename           = "debian-12-generic-amd64.img"
    image_checksum           = "5da221d8f7434ee86145e78a2c60ca45eb4ef8296535e04f6f333193225792aa8ceee3df6aea2b4ee72d6793f7312308a8b0c6a1c7ed4c7c730fa7bda1bc665f"
    image_checksum_algorithm = "sha512"
    bios                     = "seabios"
    machine_type             = "q35"
    cores                    = 2
    memory                   = 2048
    disk_size                = 30
  }
}

## VMs Configuration - Production workloads
vm_configs = [
  # Load Balancers
  {
    name              = "prod-lb-01"
    template          = "ubuntu22-prod"
    vm_id             = 100
    cores             = 4
    memory            = 4096
    disk_size         = 30
    autostart         = true
    enable_cloud_init = true
    cloud_init_user   = "ubuntu"

    network_devices = [
      {
        bridge  = "vmbr0"
        vlan_id = 10
      }
    ]

    ip_configs = [
      {
        ipv4_address = "192.168.10.10/24"
        ipv4_gateway = "192.168.10.1"
      }
    ]

    additional_disks = []

    enable_firewall = true
    firewall_rules = [
      {
        action    = "ACCEPT"
        direction = "IN"
        protocol  = "tcp"
        port      = "22"
        comment   = "SSH"
      },
      {
        action    = "ACCEPT"
        direction = "IN"
        protocol  = "tcp"
        port      = "80"
        comment   = "HTTP"
      },
      {
        action    = "ACCEPT"
        direction = "IN"
        protocol  = "tcp"
        port      = "443"
        comment   = "HTTPS"
      }
    ]

    tags = ["prod", "loadbalancer", "critical"]
  },

  # Web Servers
  {
    name              = "prod-web-01"
    template          = "ubuntu22-prod"
    vm_id             = 101
    cores             = 4
    memory            = 4096
    disk_size         = 50
    autostart         = true
    enable_cloud_init = true
    cloud_init_user   = "ubuntu"

    network_devices = [
      {
        bridge  = "vmbr0"
        vlan_id = 10
      }
    ]

    ip_configs = [
      {
        ipv4_address = "192.168.10.20/24"
        ipv4_gateway = "192.168.10.1"
      }
    ]

    additional_disks = [
      merge(local.default_disk_config, {
        interface = "scsi1"
        size      = 200
      })
    ]

    enable_firewall = true
    firewall_rules = [
      {
        action    = "ACCEPT"
        direction = "IN"
        protocol  = "tcp"
        port      = "22"
        comment   = "SSH"
      },
      {
        action    = "ACCEPT"
        direction = "IN"
        protocol  = "tcp"
        port      = "80"
        source    = "192.168.10.10"
        comment   = "HTTP from LB"
      },
      {
        action    = "ACCEPT"
        direction = "IN"
        protocol  = "tcp"
        port      = "443"
        source    = "192.168.10.10"
        comment   = "HTTPS from LB"
      }
    ]

    tags = ["prod", "web", "critical"]
  },

  {
    name              = "prod-web-02"
    template          = "ubuntu22-prod"
    vm_id             = 102
    cores             = 4
    memory            = 4096
    disk_size         = 50
    autostart         = true
    enable_cloud_init = true
    cloud_init_user   = "ubuntu"

    network_devices = [
      {
        bridge  = "vmbr0"
        vlan_id = 10
      }
    ]

    ip_configs = [
      {
        ipv4_address = "192.168.10.21/24"
        ipv4_gateway = "192.168.10.1"
      }
    ]

    additional_disks = [
      merge(local.default_disk_config, {
        interface = "scsi1"
        size      = 200
      })
    ]

    enable_firewall = true
    firewall_rules = [
      {
        action    = "ACCEPT"
        direction = "IN"
        protocol  = "tcp"
        port      = "22"
        comment   = "SSH"
      },
      {
        action    = "ACCEPT"
        direction = "IN"
        protocol  = "tcp"
        port      = "80"
        source    = "192.168.10.10"
        comment   = "HTTP from LB"
      },
      {
        action    = "ACCEPT"
        direction = "IN"
        protocol  = "tcp"
        port      = "443"
        source    = "192.168.10.10"
        comment   = "HTTPS from LB"
      }
    ]

    tags = ["prod", "web", "critical"]
  },

  # Application Servers
  {
    name              = "prod-app-01"
    template          = "debian12-prod"
    vm_id             = 110
    cores             = 8
    memory            = 8192
    disk_size         = 100
    autostart         = true
    enable_cloud_init = true
    cloud_init_user   = "debian"

    network_devices = [
      {
        bridge  = "vmbr0"
        vlan_id = 10
      }
    ]

    ip_configs = [
      {
        ipv4_address = "192.168.10.30/24"
        ipv4_gateway = "192.168.10.1"
      }
    ]

    additional_disks = [
      merge(local.default_disk_config, {
        interface = "scsi1"
        size      = 500
      })
    ]

    enable_firewall = true
    firewall_rules = [
      {
        action    = "ACCEPT"
        direction = "IN"
        protocol  = "tcp"
        port      = "22"
        comment   = "SSH"
      },
      {
        action    = "ACCEPT"
        direction = "IN"
        protocol  = "tcp"
        port      = "8080"
        source    = "192.168.10.20"
        comment   = "App from web-01"
      },
      {
        action    = "ACCEPT"
        direction = "IN"
        protocol  = "tcp"
        port      = "8080"
        source    = "192.168.10.21"
        comment   = "App from web-02"
      }
    ]

    tags = ["prod", "app", "critical"]
  },

  # Primary Database
  {
    name              = "prod-db-primary"
    template          = "debian12-prod"
    vm_id             = 120
    cores             = 8
    memory            = 16384
    disk_size         = 200
    autostart         = true
    enable_cloud_init = true
    cloud_init_user   = "debian"

    network_devices = [
      {
        bridge  = "vmbr0"
        vlan_id = 10
      }
    ]

    ip_configs = [
      {
        ipv4_address = "192.168.10.40/24"
        ipv4_gateway = "192.168.10.1"
      }
    ]

    additional_disks = [
      merge(local.default_disk_config, {
        interface = "scsi1"
        size      = 1000
        cache     = "writethrough" # Override: Extra safety for critical database
      })
    ]

    enable_firewall = true
    firewall_rules = [
      {
        action    = "ACCEPT"
        direction = "IN"
        protocol  = "tcp"
        port      = "22"
        source    = "192.168.10.0/24"
        comment   = "SSH from network"
      },
      {
        action    = "ACCEPT"
        direction = "IN"
        protocol  = "tcp"
        port      = "3306"
        source    = "192.168.10.30"
        comment   = "MySQL from app"
      },
      {
        action    = "ACCEPT"
        direction = "IN"
        protocol  = "tcp"
        port      = "3306"
        source    = "192.168.10.50"
        comment   = "MySQL from replica"
      }
    ]

    tags = ["prod", "database", "critical", "primary"]
  },

  # Database Replica
  {
    name              = "prod-db-replica"
    template          = "debian12-prod"
    vm_id             = 121
    cores             = 8
    memory            = 16384
    disk_size         = 200
    autostart         = true
    enable_cloud_init = true
    cloud_init_user   = "debian"

    network_devices = [
      {
        bridge  = "vmbr0"
        vlan_id = 10
      }
    ]

    ip_configs = [
      {
        ipv4_address = "192.168.10.50/24"
        ipv4_gateway = "192.168.10.1"
      }
    ]

    additional_disks = [
      merge(local.default_disk_config, {
        interface = "scsi1"
        size      = 1000
        cache     = "writethrough" # Override: Extra safety for critical database
      })
    ]

    enable_firewall = true
    firewall_rules = [
      {
        action    = "ACCEPT"
        direction = "IN"
        protocol  = "tcp"
        port      = "22"
        source    = "192.168.10.0/24"
        comment   = "SSH from network"
      },
      {
        action    = "ACCEPT"
        direction = "IN"
        protocol  = "tcp"
        port      = "3306"
        source    = "192.168.10.30"
        comment   = "MySQL from app"
      },
      {
        action    = "ACCEPT"
        direction = "IN"
        protocol  = "tcp"
        port      = "3306"
        source    = "192.168.10.40"
        comment   = "Replication from primary"
      }
    ]

    tags = ["prod", "database", "critical", "replica"]
  }
]

## LXC Containers - Support services
lxc_configs = [
  {
    name              = "prod-monitor"
    container_id      = 200
    template_file_id  = "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst" # Update with your actual template ID from Proxmox
    os_type           = "debian"
    storage           = "local-lvm"
    disk_size         = 50
    cores             = 4
    memory            = 2048
    memory_swap       = 2048
    autostart         = true
    unprivileged      = true
    startup_order     = 1

    network_devices = [
      {
        name    = "eth0"
        bridge  = "vmbr0"
        vlan_id = 10
      }
    ]

    ip_configs = [
      {
        ipv4_address = "dhcp"
      }
    ]

    dns_servers     = ["8.8.8.8", "8.8.4.4"]
    ssh_public_keys = []
    root_password   = null

    enable_firewall = true
    firewall_rules = [
      {
        type    = "in"
        action  = "ACCEPT"
        proto   = "tcp"
        dport   = "9090"
        source  = "192.168.10.0/24"
        comment = "Prometheus"
      },
      {
        type    = "in"
        action  = "ACCEPT"
        proto   = "tcp"
        dport   = "3000"
        source  = "192.168.10.0/24"
        comment = "Grafana"
      }
    ]

    tags = ["prod", "monitoring", "critical"]
  },

  {
    name              = "prod-logging"
    container_id      = 201
    template_file_id  = "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst" # Update with your actual template ID from Proxmox
    os_type           = "debian"
    storage           = "local-lvm"
    disk_size         = 100
    cores             = 4
    memory            = 4096
    memory_swap       = 4096
    autostart         = true
    unprivileged      = true
    startup_order     = 2

    network_devices = [
      {
        name    = "eth0"
        bridge  = "vmbr0"
        vlan_id = 10
      }
    ]

    ip_configs = [
      {
        ipv4_address = "dhcp"
      }
    ]

    dns_servers     = ["8.8.8.8", "8.8.4.4"]
    ssh_public_keys = []
    root_password   = null

    enable_firewall = true
    firewall_rules = [
      {
        type    = "in"
        action  = "ACCEPT"
        proto   = "tcp"
        dport   = "9200"
        source  = "192.168.10.0/24"
        comment = "Elasticsearch"
      },
      {
        type    = "in"
        action  = "ACCEPT"
        proto   = "tcp"
        dport   = "5044"
        source  = "192.168.10.0/24"
        comment = "Logstash"
      }
    ]

    tags = ["prod", "logging", "critical"]
  },

  {
    name              = "prod-backup"
    container_id      = 202
    template_file_id  = "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst" # Update with your actual template ID from Proxmox
    os_type           = "debian"
    storage           = "local-lvm"
    disk_size         = 500
    cores             = 4
    memory            = 2048
    memory_swap       = 2048
    autostart         = true
    unprivileged      = true
    startup_order     = 3

    network_devices = [
      {
        name    = "eth0"
        bridge  = "vmbr0"
        vlan_id = 10
      }
    ]

    ip_configs = [
      {
        ipv4_address = "dhcp"
      }
    ]

    dns_servers     = ["8.8.8.8", "8.8.4.4"]
    ssh_public_keys = []
    root_password   = null

    enable_firewall = true
    firewall_rules = [
      {
        type    = "in"
        action  = "ACCEPT"
        proto   = "tcp"
        dport   = "22"
        source  = "192.168.10.0/24"
        comment = "SSH"
      },
      {
        type    = "in"
        action  = "ACCEPT"
        proto   = "tcp"
        dport   = "873"
        source  = "192.168.10.0/24"
        comment = "Rsync"
      }
    ]

    tags = ["prod", "backup", "critical"]
  }
]

## Common Tags
tags = {
  Environment = "prod"
  ManagedBy   = "Terraform"
  Owner       = "DevOps"
  Purpose     = "Production"
  Criticality = "high"
}
