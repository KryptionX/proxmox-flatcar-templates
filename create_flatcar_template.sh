#!/bin/bash

# Official Flatcar Container Linux Template Creator for Proxmox
# Based on: https://www.flatcar.org/docs/latest/installing/community-platforms/proxmoxve/

set -e

# Variables
FLATCAR_CHANNEL="stable" # stable, beta, or alpha
IMG_URL="https://${FLATCAR_CHANNEL}.release.flatcar-linux.net/amd64-usr/current/flatcar_production_proxmoxve_image.img"
IMG_NAME="flatcar_production_proxmoxve_image.img"
TEMPL_NAME="flatcar-${FLATCAR_CHANNEL}"
VMID="10000"
MEM="4096"
CORES="4"
DISK_SIZE="40G"
DISK_STOR="local" # Common Proxmox storage
NET_BRIDGE="vmbr0"

# Configuration method choice
CONFIG_METHOD="cloudinit" # "cloudinit" or "ignition"

echo "=== Official Flatcar Container Linux Template Creator ==="
echo "Channel: $FLATCAR_CHANNEL"
echo "Config Method: $CONFIG_METHOD"
echo "Template Name: $TEMPL_NAME (VM ID: $VMID)"
echo ""

function check_vm_exists() {
  local vmid=$1
  if qm status $vmid >/dev/null 2>&1; then
    echo "❌ VM $vmid already exists. Please remove it first or use a different VMID."
    echo "To remove: qm destroy $vmid --purge"
    exit 1
  fi
}

function download_flatcar_image() {
  echo "📥 Downloading official Flatcar Proxmox image..."

  if [[ -f $IMG_NAME ]]; then
    echo "✅ Image $IMG_NAME already exists, skipping download."
    return
  fi

  echo "Downloading from: $IMG_URL"
  wget -O $IMG_NAME $IMG_URL

  if [[ ! -f $IMG_NAME ]]; then
    echo "❌ Error: Failed to download image"
    exit 1
  fi

  echo "✅ Download completed: $IMG_NAME"
}

function create_flatcar_vm_cloudinit() {
  local vmid=$1
  local templ_name=$2

  echo "🔧 Creating Flatcar VM with Cloud-Init support..."

  # Create VM with official method
  qm create $vmid \
    --name "$templ_name" \
    --cores $CORES \
    --memory $MEM \
    --net0 "virtio,bridge=$NET_BRIDGE" \
    --ostype l26 \
    --agent enabled=1

  # Import the official Flatcar Proxmox image
  echo "📦 Importing Flatcar disk image..."
  qm disk import $vmid $IMG_NAME $DISK_STOR

  # Configure storage and boot
  qm set $vmid --scsi0 $DISK_STOR:vm-$vmid-disk-0
  qm set $vmid --boot order=scsi0
  qm set $vmid --scsi1 $DISK_STOR:cloudinit

  # Resize disk
  qm disk resize $vmid scsi0 $DISK_SIZE

  echo "✅ VM $vmid created successfully with Cloud-Init support!"
  echo ""
  echo "🎯 Next steps:"
  echo "1. Use Proxmox UI Cloud-Init tab to configure:"
  echo "   - IP address, SSH keys, passwords"
  echo "   - User data for NFS mounts and Docker setup"
  echo "2. Start VM: qm start $vmid"
  echo "3. Convert to template: qm template $vmid"
}

function create_flatcar_vm_ignition() {
  local vmid=$1
  local templ_name=$2

  echo "🔧 Creating Flatcar VM with Ignition support..."

  # Create VM with official method
  qm create $vmid \
    --name "$templ_name" \
    --cores $CORES \
    --memory $MEM \
    --net0 "virtio,bridge=$NET_BRIDGE" \
    --ostype l26 \
    --agent enabled=1

  # Import the official Flatcar Proxmox image
  echo "📦 Importing Flatcar disk image..."
  qm disk import $vmid $IMG_NAME $DISK_STOR

  # Configure storage and boot
  qm set $vmid --scsi0 $DISK_STOR:vm-$vmid-disk-0
  qm set $vmid --boot order=scsi0

  # Resize disk
  qm disk resize $vmid scsi0 $DISK_SIZE

  echo "✅ VM $vmid created successfully for Ignition!"
  echo ""
  echo "🎯 Next steps for Ignition setup:"
  echo "1. Create Ignition config: nano /var/lib/vz/snippets/flatcar-$vmid.ign"
  echo "2. Configure VM to use it: qm set $vmid --args '-fw_cfg name=opt/org.flatcar-linux/config,file=/var/lib/vz/snippets/flatcar-$vmid.ign'"
  echo "3. Start VM: qm start $vmid"
  echo "4. Convert to template: qm template $vmid"
}

function convert_to_template() {
  local vmid=$1

  echo "🔄 Converting VM to template..."
  qm template $vmid
  echo "✅ Template created successfully!"
}

function cleanup() {
  echo "🧹 Cleaning up downloaded image..."
  if [[ -f $IMG_NAME ]]; then
    rm $IMG_NAME
    echo "✅ Removed $IMG_NAME"
  fi
}

function show_cloudinit_example() {
  echo ""
  echo "📋 Example Cloud-Init User Data for your NFS setup:"
  echo "=============================================="
  cat <<'EOF'
#cloud-config
# Paste this into Proxmox Cloud-Init "User Data" field

write_files:
  - path: /etc/systemd/system/mnt-app-data.mount
    content: |
      [Unit]
      Description=Mount Application Data
      After=network-online.target
      [Mount]
      What=${NFS_SERVER}:${APP_DATA_PATH}
      Where=/mnt/app/data
      Type=nfs
      Options=${NFS_OPTIONS}
      [Install]
      WantedBy=multi-user.target

runcmd:
  - mkdir -p /mnt/app/data
  - systemctl daemon-reload
  - systemctl enable mnt-app-data.mount
  - systemctl start mnt-app-data.mount
  - chown -R core:core /mnt/app
EOF
  echo "=============================================="
}

function main() {
  check_vm_exists $VMID
  download_flatcar_image

  if [[ "$CONFIG_METHOD" == "cloudinit" ]]; then
    create_flatcar_vm_cloudinit $VMID $TEMPL_NAME
    show_cloudinit_example
  else
    create_flatcar_vm_ignition $VMID $TEMPL_NAME
  fi

  # Ask user if they want to convert to template
  echo ""
  read -p "Convert VM to template now? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    convert_to_template $VMID
  else
    echo "💡 VM created but not converted to template."
    echo "Convert it later with: qm template $VMID"
  fi

  cleanup

  echo ""
  echo "🎉 Flatcar template creation completed!"
  echo "Template: $TEMPL_NAME (VM ID: $VMID)"

  if [[ "$CONFIG_METHOD" == "cloudinit" ]]; then
    echo ""
    echo "🚀 For Cloud-Init usage:"
    echo "1. Clone template: qm clone $VMID 200 --name immich-prod"
    echo "2. Configure via Proxmox UI Cloud-Init tab"
    echo "3. Start VM: qm start 200"
  else
    echo ""
    echo "🚀 For Ignition usage:"
    echo "1. Create Ignition config in /var/lib/vz/snippets/"
    echo "2. Clone and configure VM with Ignition file"
    echo "3. Start VM"
  fi

  echo ""
  echo "✨ Benefits gained:"
  echo "• Docker pre-installed and optimized"
  echo "• Automatic OS updates with rollback"
  echo "• Immutable OS (no configuration drift)"
  echo "• ~500MB footprint vs 2GB+ Debian"
  echo "• Container-native environment"
}

# Run main function
main
