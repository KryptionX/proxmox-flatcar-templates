variable "node" {
  description = "Proxmox node name"
  type        = string
}

variable "proxmox_url" {
  description = "Proxmox server IP/hostname"
  type        = string
}

variable "username" {
  description = "Proxmox API username"
  type        = string
}

variable "token" {
  description = "Proxmox API token"
  type        = string
}

variable "clone_vm_id" {
  description = "ID of the Flatcar base template VM to clone"
  type        = number
  default     = 9001
}

variable "vm_id" {
  description = "ID for the new Flatcar template"
  type        = number
  default     = 9002
}

variable "cipassword" {
  description = "Password for core user (optional, SSH keys preferred)"
  type        = string
  default     = "flatcar"
}

variable "ciuser" {
  description = "Default user for Flatcar (should be 'core')"
  type        = string
  default     = "core"
}

variable "disk_stor" {
  description = "Proxmox storage pool for disks"
  type        = string
}

variable "ipconfig" {
  description = "Cloud-Init IP configuration"
  type        = string
}

variable "ssh_username" {
  description = "SSH username for Packer connection"
  type        = string
  default     = "core"
}

variable "template_name" {
  description = "Name for the final Flatcar template"
  type        = string
  default     = "flatcar-container-template"
}

variable "insecure_skip_tls_verify" {
  description = "Skip TLS verification for Proxmox API"
  type        = bool
  default     = false
}

packer { 
  required_plugins {
    proxmox = {
      version = "~> 1"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-clone" "flatcar" {
  node                      = var.node
  proxmox_url              = "https://${var.proxmox_url}:8006/api2/json"
  token                    = var.token
  username                 = var.username
  vm_id                    = var.vm_id
  clone_vm_id              = var.clone_vm_id
  
  # VM Configuration  
  cores                    = 4
  cpu_type                 = "host"
  full_clone               = false
  insecure_skip_tls_verify = var.insecure_skip_tls_verify
  memory                   = 4096
  
  network_adapters {
    bridge                 = "vmbr0"
    model                  = "virtio"
  }
  
  os                       = "l26"
  scsi_controller          = "virtio-scsi-pci"
  ssh_username             = var.ssh_username
  template_name            = var.template_name
  vm_name                  = "Flatcar-Template"
  
  # Flatcar-specific: We'll inject the Ignition config via qm args
  # The VM will boot and apply the Ignition configuration automatically
  ssh_timeout              = "10m"
}

build {
  sources = ["source.proxmox-clone.flatcar"]
  
  # Generate Ignition file from Butane config
  provisioner "shell-local" {
    inline = [
      "echo 'Converting Butane config to Ignition...'",
      "mkdir -p /tmp/ignition",
      "butane --pretty --strict flatcar-config.bu > /tmp/ignition/config.ign",
      "echo 'Ignition file generated at /tmp/ignition/config.ign'"
    ]
  }
  
  # Copy Ignition file to Proxmox snippets directory
  # Note: This assumes you have snippets storage configured
  provisioner "shell-local" {
    environment_vars = ["IGNITION_FILE=/tmp/ignition/config.ign"]
    inline = [
      "echo 'Copying Ignition file to Proxmox snippets...'",
      "cp /tmp/ignition/config.ign /var/lib/vz/snippets/flatcar-${var.vm_id}.ign",
      "chmod 644 /var/lib/vz/snippets/flatcar-${var.vm_id}.ign"
    ]
  }
  
  # Configure VM to use Ignition file on first boot
  post-processor "shell-local" {
    inline = [
      "echo 'Configuring Flatcar VM...'",
      "qm set ${var.vm_id} --scsihw virtio-scsi-pci",
      "qm set ${var.vm_id} --boot c --bootdisk scsi0",
      "qm set ${var.vm_id} --ciuser ${var.ciuser}",
      "qm set ${var.vm_id} --cipassword ${var.cipassword}",
      "qm set ${var.vm_id} --vga std",
      "qm set ${var.vm_id} --ipconfig0 ${var.ipconfig}",
      "qm set ${var.vm_id} --agent enabled=1",
      
      # Add Ignition configuration via firmware config
      "qm set ${var.vm_id} --args '-fw_cfg name=opt/org.flatcar-linux/config,file=/var/lib/vz/snippets/flatcar-${var.vm_id}.ign'",
      
      # Restart VM to apply Ignition config
      "echo 'Restarting VM to apply Ignition configuration...'",
      "qm shutdown ${var.vm_id} --timeout 60 || true",
      "sleep 10",
      "qm start ${var.vm_id}",
      "sleep 30",
      
      "echo 'Flatcar VM template configured successfully!'",
      "echo 'Ignition file: /var/lib/vz/snippets/flatcar-${var.vm_id}.ign'"
    ]
  }
} 