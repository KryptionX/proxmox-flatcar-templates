# Proxmox Flatcar Templates

**Automated Flatcar Container Linux template creation for Proxmox VE using Packer.**

> **Disclaimer**: This is an unofficial personal project. Not affiliated with Flatcar or Proxmox.

## Overview

This repository provides tools for creating Flatcar Container Linux templates in Proxmox VE, optimized for container workloads. Flatcar offers automatic updates, immutable OS design, and Docker pre-installed, making it ideal for containerized applications.

## Features

- **Official Flatcar Proxmox Images**: Uses dedicated Proxmox images from Flatcar
- **Dual Configuration Support**: Choose between Cloud-Init (easy) or Ignition (advanced)
- **Secure Templating System**: Environment-based configuration with git protection
- **Container Optimized**: Pre-configured for Docker workloads with NFS support
- **Production Ready**: Includes validation, error handling, and security best practices

## Quick Start

### Prerequisites

- Proxmox VE 6.0+
- Packer installed
- SSH access to Proxmox host

### Configuration

1. **Set up your environment variables:**

   ```bash
   cd flatcar/
   cp flatcar-variables.env.example flatcar-variables.env
   # Edit flatcar-variables.env with your actual values
   ```

2. **Generate configuration files:**

   ```bash
   ./generate-config.sh
   ```

3. **Create the template:**
   ```bash
   ./create_flatcar_template.sh
   packer build -var-file=flatcar.pkrvars.hcl flatcar.pkr.hcl
   ```

## Configuration Options

### Cloud-Init (Recommended)

Uses Proxmox's built-in Cloud-Init support. Familiar workflow with GUI configuration.

**Benefits:**

- ✅ Use Proxmox UI Cloud-Init tab
- ✅ Minimal learning curve
- ✅ Same workflow as other cloud images
- ✅ Dynamic configuration per VM

### Ignition (Advanced)

File-based immutable configuration system native to Flatcar.

**Benefits:**

- ✅ Infrastructure as Code
- ✅ Version-controlled configuration
- ✅ No configuration drift
- ✅ Advanced systemd integration

## Architecture

### Flatcar Benefits

- **Immutable OS**: Read-only root filesystem prevents configuration drift
- **Automatic Updates**: Seamless OS updates with rollback capability
- **Container Optimized**: Docker pre-installed and optimized
- **Small Footprint**: ~500MB vs 2GB+ for traditional distributions
- **Security Focused**: Minimal attack surface, regular security updates

### Template Structure

```
flatcar/
├── create_flatcar_template.sh          # Template creation script
├── flatcar.pkr.hcl                     # Packer configuration
├── flatcar-config.bu                   # Butane config template
├── flatcar-variables.env.example       # Variable template
├── generate-config.sh                  # Config generation script
├── cloud-init-example.yaml             # Cloud-Init example
└── README.md                           # This file
```

## Usage

### For Container Workloads

The template is pre-configured for common container use cases:

- **Docker**: Pre-installed and configured
- **NFS Mounts**: Automatic mounting of network storage
- **User Management**: Secure SSH access with key-based authentication
- **System Tools**: Essential tools for container management

### NFS Integration

Configure NFS mounts via environment variables:

```bash
# In flatcar-variables.env
NFS_SERVER="your-nfs-server.local"
APP_DATA_PATH="/mnt/data/apps"
```

The template automatically creates systemd mount units for reliable NFS mounting.

## Security

### Template System Security

- **Environment Variables**: Sensitive data stored in `.env` files
- **Git Protection**: Automatic `.gitignore` for sensitive files
- **Validation**: Prevents placeholder values in production
- **TLS Verification**: Configurable for different environments

### Production Recommendations

- Use dedicated SSH keys for deployment
- Enable TLS verification for production environments
- Use limited-scope Proxmox API tokens
- Review generated configurations before deployment

## Flatcar Image Channels

Choose the appropriate Flatcar release channel:

- **Stable**: Recommended for production workloads
- **Beta**: Newer features, tested but not production-ready
- **Alpha**: Latest features, frequent updates

## Troubleshooting

### Common Issues

1. **Template Import Fails**: Ensure Proxmox storage has sufficient space
2. **SSH Access Denied**: Verify SSH public key in configuration
3. **NFS Mount Fails**: Check network connectivity and NFS server configuration
4. **Docker Issues**: Verify container runtime is enabled

### Logs

- **Cloud-Init**: `/var/log/cloud-init-output.log`
- **Ignition**: `journalctl -u ignition-*`
- **Docker**: `journalctl -u docker.service`

## Contributing

This is a community project. Contributions welcome via pull requests.

## License

MIT License - See LICENSE file for details.

## References

- [Flatcar Container Linux](https://www.flatcar.org/)
- [Proxmox VE](https://www.proxmox.com/en/proxmox-ve)
- [Official Flatcar Proxmox Documentation](https://www.flatcar.org/docs/latest/installing/community-platforms/proxmoxve/)
- [Packer](https://www.packer.io/)
