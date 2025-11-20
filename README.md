# Handbuilt Linux: Custom Linux Distribution from Scratch

A minimal, customizable Linux distribution built from scratch using the Linux kernel, BusyBox, and Syslinux bootloader. This project demonstrates how to build a bootable Linux system with full control over every component.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-ready-brightgreen.svg)](Dockerfile)
[![Linux](https://img.shields.io/badge/kernel-latest-orange.svg)](https://github.com/torvalds/linux)

## 📋 Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Building from Source](#building-from-source)
- [Usage](#usage)
- [Project Structure](#project-structure)
- [Configuration](#configuration)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## ✨ Features

- **Minimal footprint**: Only essential components included
- **From scratch**: Built directly from kernel and BusyBox sources
- **Multi-stage Docker build**: Optimized build process with caching
- **Bootable ISO**: Creates a bootable ISO image
- **Custom init system**: Simple, transparent init process
- **QEMU ready**: Easy testing with QEMU emulator
- **Configurable**: Customize kernel and BusyBox configurations
- **Fast builds**: Parallel compilation with caching

## 🔧 Prerequisites

### For Docker Build (Recommended)

- Docker 20.10 or later
- Docker Compose (optional)
- 4GB free disk space
- 2GB RAM minimum

### For Manual Build

- Linux system (Debian/Ubuntu recommended)
- Build tools: `gcc`, `make`, `bison`, `flex`
- Additional packages:

  ```bash
  sudo apt-get install build-essential libncurses-dev bison flex \
    libssl-dev libelf-dev bc cpio git wget curl syslinux \
    dosfstools genisoimage qemu-system-x86
  ```

## 🚀 Quick Start

### Using Docker (Recommended)

1. **Clone the repository**

   ```bash
   git clone https://github.com/ehsanghaffar/handbuilt-linux.git
   cd handbuilt-linux
   ```

2. **Build the distribution**

   ```bash
   docker build -t handbuilt-linux .
   ```

3. **Extract the ISO**

   ```bash
   docker run --rm handbuilt-linux cat /distro/output.iso > output.iso
   ```

4. **Test with QEMU**

   ```bash
   qemu-system-x86_64 -cdrom output.iso -m 512M
   ```

### Using Docker Compose

```bash
docker-compose up --build
```

## 🏗️ Building from Source

### Step 1: Build with Docker

The multi-stage Dockerfile handles all build steps:

```bash
# Build the complete image
docker build -t handbuilt-linux .

# Or build specific stages
docker build --target kernel-builder -t linux-kernel .
docker build --target busybox-builder -t busybox-build .
docker build --target iso-builder -t linux-iso .
```

### Step 2: Extract Build Artifacts

```bash
# Extract ISO
docker run --rm handbuilt-linux cat /distro/output.iso > output.iso

# Extract kernel
docker run --rm handbuilt-linux cat /distro/bzImage > bzImage

# Extract initramfs
docker run --rm handbuilt-linux cat /distro/initramfs > initramfs
```

### Step 3: Create Bootable USB (Optional)

```bash
# Replace /dev/sdX with your USB device (BE CAREFUL!)
sudo dd if=output.iso of=/dev/sdX bs=4M status=progress
sudo sync
```

## 📖 Usage

### Running with QEMU

**Boot from ISO:**

```bash
qemu-system-x86_64 -cdrom output.iso -m 512M
```

**Boot from kernel and initramfs directly:**

```bash
qemu-system-x86_64 \
  -kernel bzImage \
  -initrd initramfs \
  -append "console=ttyS0" \
  -nographic \
  -m 512M
```

**With networking:**

```bash
qemu-system-x86_64 \
  -cdrom output.iso \
  -m 512M \
  -netdev user,id=net0 \
  -device e1000,netdev=net0
```

### Building Boot Image

Use the enhanced `build.sh` script to create a bootable disk image:

```bash
# Basic usage
./build.sh

# Custom size
./build.sh --size 100

# Custom output name
./build.sh --output my-boot.img

# Verbose output
./build.sh --verbose

# Show help
./build.sh --help
```

### Interactive Shell Commands

Once booted, you have access to BusyBox utilities:

```bash
# List all available commands
busybox --list

# File operations
ls, cat, cp, mv, rm, mkdir, rmdir, touch

# System utilities
ps, top, free, df, mount, umount, hostname

# Network utilities
ifconfig, ping, wget, nc

# Text processing
grep, sed, awk, sort, uniq, head, tail
```

## 📁 Project Structure

```bash
handbuilt-linux/
├── Dockerfile              # Multi-stage Docker build
├── docker-compose.yml      # Docker Compose configuration
├── Makefile               # Build automation
├── README.md              # This file
├── LICENSE                # Project license
├── .gitignore             # Git ignore rules
│
├── build.sh               # Boot image builder script
├── init.sh                # Init system script (PID 1)
├── syslinux.cfg           # Bootloader configuration
│
├── linux.config           # Linux kernel configuration
├── busybox.config         # BusyBox configuration
│
├── scripts/               # Helper scripts
│   ├── test.sh           # Testing script
│   ├── extract.sh        # Extract artifacts from Docker
│   └── clean.sh          # Cleanup build artifacts
│
├── docs/                  # Additional documentation
│   ├── BUILDING.md       # Detailed build instructions
│   ├── CUSTOMIZING.md    # Customization guide
│   └── TROUBLESHOOTING.md # Common issues and solutions
│
└── .github/
    └── workflows/
        └── build.yml      # CI/CD pipeline
```

## ⚙️ Configuration

### Kernel Configuration

To customize the kernel:

```bash
# Start configuration menu
docker run -it --rm -v $(pwd):/work handbuilt-linux bash
cd /opt/mydistro/linux
make menuconfig
# Save configuration
cp .config /work/linux.config
```

### BusyBox Configuration

To customize BusyBox:

```bash
# Start configuration menu
docker run -it --rm -v $(pwd):/work handbuilt-linux bash
cd /opt/mydistro/busybox
make menuconfig
# Save configuration
cp .config /work/busybox.config
```

### Init System

Modify `init.sh` to customize:

- Hostname
- Mounted filesystems
- Network configuration
- Startup services
- Environment variables

### Bootloader

Modify `syslinux.cfg` to customize:

- Boot timeout
- Kernel parameters
- Boot menu options
- Default boot entry

## 🔥 Advanced Usage

### Custom Packages

Add custom software to the initramfs:

```dockerfile
# In Dockerfile, add after BusyBox installation:
RUN cd /build/initramfs && \
    wget https://example.com/package.tar.gz && \
    tar xzf package.tar.gz && \
    rm package.tar.gz
```

### Multi-Architecture Support

Build for different architectures:

```bash
# ARM64
docker build --build-arg ARCH=arm64 -t handbuilt-linux-arm64 .

# ARM
docker build --build-arg ARCH=arm -t handbuilt-linux-arm .
```

### Persistent Storage

Mount a persistent volume:

```bash
qemu-system-x86_64 \
  -cdrom output.iso \
  -m 512M \
  -drive file=data.img,format=raw
```

### Network Boot (PXE)

Extract kernel and initramfs for network booting:

```bash
# Extract files
docker run --rm handbuilt-linux cat /distro/bzImage > /tftpboot/bzImage
docker run --rm handbuilt-linux cat /distro/initramfs > /tftpboot/initramfs

# Configure PXE
cat > /tftpboot/pxelinux.cfg/default << EOF
DEFAULT linux
LABEL linux
    KERNEL bzImage
    APPEND initrd=initramfs
EOF
```

## 🐛 Troubleshooting

### Common Issues

**Build fails with "out of space" error:**

```bash
# Increase Docker disk space or clean up
docker system prune -a
```

**QEMU shows black screen:**

```bash
# Use serial console
qemu-system-x86_64 -cdrom output.iso -nographic
```

**Kernel panic on boot:**

```bash
# Check initramfs was created correctly
file initramfs
# Should show: "gzip compressed data"
```

**Permission denied when mounting:**

```bash
# Run build.sh with sudo
sudo ./build.sh
```

### Debug Mode

Enable verbose logging:

```bash
# Build script
./build.sh --verbose

# QEMU with debug output
qemu-system-x86_64 -cdrom output.iso -d guest_errors,cpu_reset
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Linux Kernel](https://kernel.org/) - The core of the operating system
- [BusyBox](https://busybox.net/) - The Swiss Army Knife of Embedded Linux
- [Syslinux](https://www.syslinux.org/) - Lightweight bootloader
- [QEMU](https://www.qemu.org/) - Emulator for testing

## 📚 Resources

- [Linux From Scratch](http://www.linuxfromscratch.org/)
- [Kernel Build Documentation](https://www.kernel.org/doc/html/latest/kbuild/index.html)
- [BusyBox Documentation](https://busybox.net/docs/)
- [Syslinux Wiki](https://wiki.syslinux.org/)

## 📞 Support

- Create an issue for bug reports
- Start a discussion for questions
- Check existing issues before creating new ones
