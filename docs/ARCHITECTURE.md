# Architecture Overview

This document describes the architecture and design decisions of the handbuilt-linux project.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       Docker Build Process                   │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌───────────────┐    ┌───────────────┐    ┌─────────────┐ │
│  │ Source Stage  │ -> │  Build Stage  │ -> │ Export Stage│ │
│  └───────────────┘    └───────────────┘    └─────────────┘ │
│         │                     │                     │        │
│         v                     v                     v        │
│  ┌───────────┐         ┌───────────┐         ┌──────────┐  │
│  │  Linux    │         │  Kernel   │         │   ISO    │  │
│  │  Sources  │         │  bzImage  │         │  Image   │  │
│  └───────────┘         └───────────┘         └──────────┘  │
│  ┌───────────┐         ┌───────────┐         ┌──────────┐  │
│  │ BusyBox   │         │ initramfs │         │ Boot Img │  │
│  │  Sources  │         │  Archive  │         └──────────┘  │
│  └───────────┘         └───────────┘                        │
│  ┌───────────┐                                              │
│  │ Syslinux  │                                              │
│  │  Sources  │                                              │
│  └───────────┘                                              │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## Component Overview

### 1. Build System

#### Dockerfile
Multi-stage build with 8 distinct stages:

1. **builder-base**: Base image with build dependencies
2. **source-downloader**: Downloads and caches sources
3. **kernel-builder**: Compiles Linux kernel
4. **busybox-builder**: Compiles BusyBox
5. **initramfs-builder**: Creates initramfs archive
6. **iso-builder**: Assembles bootable ISO
7. **export-stage**: Exports build artifacts
8. **runtime**: Final minimal runtime image

#### Benefits
- **Layer caching**: Faster rebuilds
- **Parallel builds**: Independent stages can build concurrently
- **Size optimization**: Final image only contains necessary artifacts
- **Security**: Non-root user, minimal attack surface

### 2. Linux Kernel

**Source**: torvalds/linux (latest)

**Configuration**: `linux.config`
- Minimal feature set
- x86_64 architecture
- Required drivers only
- No unnecessary modules

**Build Process**:
```bash
make olddefconfig
make -j$(nproc)
strip --strip-debug arch/x86/boot/bzImage
```

**Output**: `bzImage` (~5-10MB)

### 3. BusyBox (Userspace)

**Source**: git.busybox.net/busybox (latest)

**Configuration**: `busybox.config`
- Essential utilities only
- Static linking
- Minimal size

**Provides**:
- Shell (sh)
- Core utilities (ls, cp, mv, etc.)
- System utilities (mount, ps, top, etc.)
- Network utilities (ifconfig, ping, wget, etc.)

**Output**: Single static binary (~1-2MB)

### 4. Init System

**File**: `init.sh`

**Responsibilities**:
- Mount essential filesystems (/proc, /sys, /dev, /tmp, /run)
- Populate /dev with device nodes
- Set hostname
- Configure environment
- Start shell (PID 1)

**Design Philosophy**:
- Simple and transparent
- No complex service management
- Easy to understand and modify
- Minimal dependencies

### 5. Bootloader

**Technology**: Syslinux/ISOLINUX

**Configuration**: `syslinux.cfg`

**Boot Process**:
1. BIOS/UEFI loads bootloader
2. Bootloader loads kernel (bzImage)
3. Kernel decompresses and initializes
4. Kernel mounts initramfs
5. Kernel executes /init (init.sh)
6. Init sets up environment
7. Shell started

### 6. Build Scripts

#### build.sh
Creates bootable disk image with:
- Error handling and validation
- Logging with colors
- Command-line options
- Cleanup on exit

#### scripts/
- `extract.sh`: Extract artifacts from Docker
- `test.sh`: Automated testing
- `clean.sh`: Cleanup build artifacts

### 7. Automation

#### Makefile
Provides convenient targets for:
- Building Docker image
- Extracting artifacts
- Running tests
- QEMU testing
- Cleanup operations

#### docker-compose.yml
Defines services:
- `builder`: Builds distribution
- `dev`: Development environment
- `qemu`: Testing environment

#### GitHub Actions
Automated CI/CD pipeline:
- Build on every push
- Run tests
- Security scanning
- Artifact publishing
- Release automation

## Data Flow

### Build Flow

```
Source Code
    ↓
Docker Build
    ↓
┌─────────────────────┐
│  Parallel Builds    │
│  ┌───────┐ ┌──────┐│
│  │Kernel │ │BusyBx││
│  └───┬───┘ └───┬──┘│
└──────┼─────────┼───┘
       │         │
       ↓         ↓
   bzImage   initramfs
       │         │
       └────┬────┘
            ↓
      Combine with
       Bootloader
            ↓
        ISO Image
```

### Boot Flow

```
Power On
    ↓
BIOS/UEFI
    ↓
Bootloader (Syslinux)
    ↓
Load Kernel (bzImage)
    ↓
Kernel Init
    ↓
Mount initramfs
    ↓
Execute /init (PID 1)
    ↓
Mount Filesystems
    ↓
Device Setup
    ↓
Shell
```

## Security Considerations

### Build-time Security
- Multi-stage builds isolate build environment
- No build tools in final image
- Minimal dependencies
- Regular source updates

### Runtime Security
- Non-root user in Docker
- Minimal attack surface
- No network services by default
- Read-only root filesystem possible

### Supply Chain Security
- Verified source repositories
- Checksums for downloads
- Security scanning in CI
- Dependency pinning possible

## Performance Optimizations

### Build Performance
- Layer caching
- Parallel compilation
- Build cache mounts
- Incremental builds

### Runtime Performance
- Static linking (no dynamic loading overhead)
- Minimal kernel
- Fast boot time (~1-2 seconds)
- Low memory footprint (~10-20MB)

### Size Optimizations
- Strip debug symbols
- Minimal kernel configuration
- Single BusyBox binary
- Compressed initramfs

## Extensibility

### Adding Packages
```dockerfile
# In busybox-builder stage
RUN cd /build/initramfs && \
    wget https://example.com/package.tar.gz && \
    tar xzf package.tar.gz
```

### Custom Init Scripts
Modify `init.sh` or add to `/etc/init.d/`

### Kernel Modules
Enable in `linux.config`:
```bash
make menuconfig
# Enable desired modules
cp .config linux.config
```

### Network Services
Add to `init.sh`:
```bash
# Start network
ifconfig eth0 up
udhcpc -i eth0

# Start services
httpd -h /www
```

## Testing Strategy

### Unit Tests
- Script syntax validation
- File existence checks
- Format validation

### Integration Tests
- Full build process
- Docker image testing
- Artifact extraction

### System Tests
- QEMU boot testing
- Functional testing
- Performance benchmarks

## Future Enhancements

### Planned Features
- [ ] UEFI boot support
- [ ] ARM architecture support
- [ ] Package manager integration
- [ ] Init service management
- [ ] Network configuration tool
- [ ] Persistent storage support

### Under Consideration
- [ ] Systemd alternative
- [ ] Container runtime
- [ ] Full development environment
- [ ] Desktop environment option

## Resources

- [Linux From Scratch](http://www.linuxfromscratch.org/)
- [Kernel Build System](https://www.kernel.org/doc/html/latest/kbuild/)
- [BusyBox](https://busybox.net/docs/)
- [Syslinux](https://wiki.syslinux.org/)
