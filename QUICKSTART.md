# Quick Start Guide

Get up and running with handbuilt-linux in 5 minutes!

## Prerequisites

- Docker installed and running
- 4GB free disk space
- (Optional) QEMU for testing

## Three Simple Steps

### 1. Build

```bash
# Clone the repository (if not already)
git clone https://github.com/yourusername/handbuilt-linux.git
cd handbuilt-linux

# Build using Make (recommended)
make build

# Or build with Docker directly
docker build -t handbuilt-linux .
```

**Build time**: 20-30 minutes (first build), 5-10 minutes (cached)

### 2. Extract

```bash
# Extract ISO image
make iso

# Or extract all artifacts
make extract
```

### 3. Run

```bash
# Test with QEMU
make qemu

# Or run manually
qemu-system-x86_64 -cdrom output.iso -m 512M
```

## Common Commands

```bash
# Full build and test
make build test

# Extract and run
make extract qemu-nographic

# Clean and rebuild
make clean build

# Enter development shell
make shell

# Show all available commands
make help
```

## Docker Compose (Alternative)

```bash
# Build and extract artifacts
docker-compose up builder

# Interactive development
docker-compose run dev

# Test with QEMU
docker-compose --profile test up qemu
```

## Next Steps

- **Customize kernel**: Edit `linux.config` and rebuild
- **Customize BusyBox**: Edit `busybox.config` and rebuild
- **Modify init**: Edit `init.sh` to customize boot process
- **Read the docs**: Check `docs/` for detailed information

## Troubleshooting

**Build fails?**

```bash
make clean-all
docker system prune -f
make build
```

**Permission denied?**

```bash
sudo make build
# Or add your user to docker group
sudo usermod -aG docker $USER
```

**QEMU not found?**

```bash
# macOS
brew install qemu

# Ubuntu/Debian
sudo apt-get install qemu-system-x86

# Or use Docker for testing
docker run --privileged -v $(pwd):/images tianon/qemu \
    qemu-system-x86_64 -cdrom /images/output.iso -nographic
```

## What's Included

- **Linux Kernel**: Latest from Linus Torvalds
- **BusyBox**: Swiss Army Knife of embedded Linux
- **Syslinux**: Lightweight bootloader
- **Custom Init**: Simple, transparent init system

## File Locations

```bash
output.iso      # Bootable ISO image
bzImage         # Linux kernel
initramfs       # Initial RAM filesystem
boot.img        # Bootable disk image (after build.sh)
```

## Quick Demo

```bash
# One-liner: Build and run
make build extract qemu-nographic

# Inside the system, try:
busybox --list    # List all available commands
cat /proc/cpuinfo # View CPU information
free              # Check memory usage
ps                # List processes
```

## Tips

1. **First build is slow** - Subsequent builds use cache
2. **Use make** - Easier than raw Docker commands
3. **Read the README** - Comprehensive documentation available
4. **Check the Makefile** - See all available commands

## Resources

- Full documentation: [README.md](README.md)
- Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Contributing: [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)

---

**Need help?** Open an issue on GitHub!
