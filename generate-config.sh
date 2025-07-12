#!/bin/bash

# Flatcar Configuration Generator
# This script processes template files and substitutes environment variables

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VARIABLES_FILE="${SCRIPT_DIR}/flatcar-variables.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Flatcar Configuration Generator ==="
echo ""

# Check if variables file exists
if [[ ! -f "$VARIABLES_FILE" ]]; then
  echo -e "${RED}❌ Variables file not found: $VARIABLES_FILE${NC}"
  echo ""
  echo "📋 Setup Instructions:"
  echo "1. Copy the template: cp flatcar-variables.env.example flatcar-variables.env"
  echo "2. Edit your variables: nano flatcar-variables.env"
  echo "3. Run this script again: ./generate-config.sh"
  echo ""
  exit 1
fi

# Source the variables
echo "📥 Loading variables from: $VARIABLES_FILE"
source "$VARIABLES_FILE"

# Validate required variables
required_vars=(
  "SPEEDFORCE_SERVER"
  "ZEPHYR_SERVER"
  "SOLO_SSD_SERVER"
  "THANOS_DIRECT_IP"
  "SSH_PUBLIC_KEY"
  "USER_PASSWORD_HASH"
  "PROXMOX_IP"
  "PROXMOX_NODE"
  "PROXMOX_USER"
  "PROXMOX_TOKEN"
)

missing_vars=()
for var in "${required_vars[@]}"; do
  if [[ -z "${!var}" || "${!var}" == *"your-"* ]]; then
    missing_vars+=("$var")
  elif [[ "$var" == "SSH_PUBLIC_KEY" && "${!var}" == *"AAAAC3... your-actual-ssh-key"* ]]; then
    # Check for the specific placeholder text, not just AAAAC3
    missing_vars+=("$var")
  elif [[ "$var" == "USER_PASSWORD_HASH" && "${!var}" == *'$1$salt$your-actual-password-hash'* ]]; then
    # Check for the specific placeholder text
    missing_vars+=("$var")
  fi
done

if [[ ${#missing_vars[@]} -gt 0 ]]; then
  echo -e "${RED}❌ Please update these variables in $VARIABLES_FILE:${NC}"
  for var in "${missing_vars[@]}"; do
    echo "   - $var"
  done
  echo ""
  exit 1
fi

echo -e "${GREEN}✅ All required variables are set${NC}"
echo ""

# Function to process template files
process_template() {
  local template_file="$1"
  local output_file="$2"

  echo "🔧 Processing: $template_file → $output_file"

  # Use envsubst to substitute environment variables
  envsubst <"$template_file" >"$output_file"

  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}   ✅ Generated: $output_file${NC}"
  else
    echo -e "${RED}   ❌ Failed to generate: $output_file${NC}"
    return 1
  fi
}

# Generate Packer variables file
echo "📝 Generating configuration files..."
echo ""

cat >"${SCRIPT_DIR}/flatcar.pkrvars.hcl" <<EOF
# Auto-generated Packer variables - DO NOT EDIT MANUALLY
# Generated from: flatcar-variables.env
# Regenerate with: ./generate-config.sh

node                      = "${PROXMOX_NODE}"
proxmox_url              = "${PROXMOX_IP}"
username                 = "${PROXMOX_USER}"
token                    = "${PROXMOX_TOKEN}"
clone_vm_id              = 9001
vm_id                    = 9002
cipassword               = "flatcar"
ciuser                   = "core"
disk_stor                = "${STORAGE_POOL}"
ipconfig                 = "gw=${GATEWAY},ip=${VM_IP_RANGE}"
ssh_username             = "core"
template_name            = "flatcar-container-template"
insecure_skip_tls_verify = ${SKIP_TLS_VERIFY}
EOF

echo -e "${GREEN}✅ Generated: flatcar.pkrvars.hcl${NC}"

# Process Butane config template
process_template "${SCRIPT_DIR}/flatcar-config.bu" "${SCRIPT_DIR}/flatcar-config-processed.bu"

# Generate cloud-init example with real values
cat >"${SCRIPT_DIR}/cloud-init-example.yaml" <<EOF
#cloud-config
# Generated cloud-init configuration with your actual NFS infrastructure
# Copy this into Proxmox Cloud-Init "User Data" field

write_files:
  # speedforce Configuration Server
  - path: /etc/systemd/system/mnt-speedforce.mount
    content: |
      [Unit]
      Description=Mount speedforce NFS configuration server
      After=network-online.target
      [Mount]
      What=${SPEEDFORCE_SERVER}:/
      Where=${SPEEDFORCE_MOUNT_POINT}
      Type=nfs
      Options=${SPEEDFORCE_OPTIONS}
      [Install]
      WantedBy=multi-user.target

  # Zephyr Media Library (Granular Security)
  - path: /etc/systemd/system/mnt-zephyr-media.mount
    content: |
      [Unit]
      Description=Mount Zephyr Media library
      After=network-online.target
      [Mount]
      What=${ZEPHYR_SERVER}:${ZEPHYR_MEDIA_PATH}
      Where=${ZEPHYR_MEDIA_MOUNT}
      Type=nfs
      Options=${ZEPHYR_OPTIONS}
      [Install]
      WantedBy=multi-user.target

  # Immich Photos via thanosDirect
  - path: /etc/systemd/system/mnt-immich-photos.mount
    content: |
      [Unit]
      Description=Mount Immich photo storage via thanosDirect
      After=network-online.target
      [Mount]
      What=${THANOS_DIRECT_IP}:${IMMICH_PHOTOS_NFS_PATH}
      Where=${IMMICH_PHOTOS_MOUNT_POINT}
      Type=nfs
      Options=${IMMICH_PHOTOS_OPTIONS}
      [Install]
      WantedBy=multi-user.target

runcmd:
  - mkdir -p ${SPEEDFORCE_MOUNT_POINT} ${ZEPHYR_MEDIA_MOUNT} ${IMMICH_PHOTOS_MOUNT_POINT}
  - systemctl daemon-reload
  - systemctl enable mnt-speedforce.mount mnt-zephyr-media.mount mnt-immich-photos.mount
  - systemctl start mnt-speedforce.mount mnt-zephyr-media.mount mnt-immich-photos.mount
  - chown -R core:core /mnt/speedforce /mnt/Zephyr /mnt/immich
  - echo "🚀 NFS infrastructure ready for container workloads"
EOF

echo -e "${GREEN}✅ Generated: cloud-init-example.yaml${NC}"

echo ""
echo "🎉 Configuration generation completed!"
echo ""
echo "📁 Generated files:"
echo "   • flatcar.pkrvars.hcl        (Packer variables with your values)"
echo "   • flatcar-config-processed.bu (Butane config with your values)"
echo "   • cloud-init-example.yaml     (Cloud-init config with your values)"
echo ""
echo "🚀 Next steps:"
echo "   1. Review the generated files"
echo "   2. Run: ./create_flatcar_template.sh"
echo "   3. Run: packer build -var-file=flatcar.pkrvars.hcl flatcar.pkr.hcl"
echo ""
echo -e "${YELLOW}🔒 Security reminder: Add these to .gitignore:${NC}"
echo "   • flatcar-variables.env"
echo "   • flatcar.pkrvars.hcl"
echo "   • flatcar-config-processed.bu"
echo "   • cloud-init-example.yaml"
