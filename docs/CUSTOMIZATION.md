# Customization Guide

This guide shows you how to customize various aspects of the handbuilt-linux distribution.

## Table of Contents

- [Kernel Customization](#kernel-customization)
- [BusyBox Customization](#busybox-customization)
- [Init System Customization](#init-system-customization)
- [Bootloader Customization](#bootloader-customization)
- [Adding Software](#adding-software)
- [Network Configuration](#network-configuration)
- [Advanced Customization](#advanced-customization)

## Kernel Customization

### Using menuconfig

The easiest way to customize the kernel:

```bash
# Start kernel configuration menu
docker run -it --rm -v $(pwd):/work handbuilt-linux bash -c \
    "cd /opt/mydistro/linux && make menuconfig && cp .config /work/linux.config"

# Rebuild with new configuration
make clean build
```

### Common Kernel Options

#### Enable Networking

```
Networking support --->
    [*] Networking support
    Networking options --->
        [*] TCP/IP networking
        [*] IP: kernel level autoconfiguration
```

#### Enable USB Support

```
Device Drivers --->
    [*] USB support --->
        <*> EHCI HCD (USB 2.0) support
        <*> OHCI HCD support
        <*> USB Mass Storage support
```

#### Enable Filesystem Support

```
File systems --->
    <*> The Extended 4 (ext4) filesystem
    <*> FUSE (Filesystem in Userspace) support
    DOS/FAT/NT Filesystems --->
        <*> VFAT (Windows-95) fs support
```

### Manual Configuration

Edit `linux.config` directly:

```bash
# Enable feature
CONFIG_FEATURE_NAME=y

# Enable as module
CONFIG_FEATURE_NAME=m

# Disable feature
# CONFIG_FEATURE_NAME is not set
```

## BusyBox Customization

### Using menuconfig

```bash
# Start BusyBox configuration menu
docker run -it --rm -v $(pwd):/work handbuilt-linux bash -c \
    "cd /opt/mydistro/busybox && make menuconfig && cp .config /work/busybox.config"

# Rebuild
make clean build
```

### Common BusyBox Options

#### Enable All Applets

```
Busybox Settings --->
    [*] Build BusyBox as a static binary (no shared libs)

[*] Enable all applets (to include everything)
```

#### Network Utilities

```
Networking Utilities --->
    [*] httpd
    [*] ftpd
    [*] telnetd
    [*] wget
    [*] nc (netcat)
```

#### Text Editors

```
Editors --->
    [*] vi
    [*] sed
    [*] awk
```

## Init System Customization

### Basic Customization

Edit `init.sh` to customize the boot process:

```bash
#!/bin/sh

# Your custom initialization here

# Example: Set custom hostname
HOSTNAME="my-custom-name"
hostname "${HOSTNAME}"

# Example: Mount additional filesystems
mkdir -p /data
mount -t tmpfs tmpfs /data

# Example: Start network
ifconfig eth0 up
udhcpc -i eth0 -s /etc/udhcpc/default.script

# Example: Start services
/usr/sbin/httpd -h /www
/usr/sbin/telnetd

# Drop to shell
exec /bin/sh
```

### Adding Startup Scripts

Create `/etc/init.d/` directory and add scripts:

```bash
# In Dockerfile, after copying init.sh:
RUN mkdir -p /build/initramfs/etc/init.d

COPY startup-scripts/* /build/initramfs/etc/init.d/
RUN chmod +x /build/initramfs/etc/init.d/*
```

Then modify `init.sh`:

```bash
# Run startup scripts
for script in /etc/init.d/S*; do
    [ -x "$script" ] && "$script" start
done
```

### Environment Variables

Customize environment in `init.sh`:

```bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export HOME="/root"
export USER="root"
export HOSTNAME="handbuilt-linux"
export TERM="linux"
export PS1='\[\033[1;32m\]\u@\h\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]\$ '
```

## Bootloader Customization

### Syslinux Configuration

Edit `syslinux.cfg`:

```cfg
# Change default boot entry
DEFAULT my-custom-entry

# Change timeout (in deciseconds)
TIMEOUT 50

# Add custom boot entry
LABEL my-custom-entry
    MENU LABEL My Custom Linux
    KERNEL /bzImage
    APPEND initrd=/initramfs custom_param=value
```

### Boot Parameters

Common kernel boot parameters:

```
quiet           # Suppress most boot messages
loglevel=7      # Verbose kernel messages
console=ttyS0   # Serial console output
root=/dev/sda1  # Root filesystem device
ro              # Mount root read-only
rw              # Mount root read-write
init=/bin/sh    # Custom init program
```

## Adding Software

### Method 1: Add to Initramfs

Edit Dockerfile to add software during build:

```dockerfile
# After BusyBox installation
FROM busybox-builder AS custom-software

WORKDIR /build/initramfs

# Download and install custom software
RUN wget https://example.com/software.tar.gz && \
    tar xzf software.tar.gz && \
    cd software && \
    ./configure --prefix=/usr && \
    make && \
    make install DESTDIR=/build/initramfs && \
    cd .. && \
    rm -rf software.tar.gz software
```

### Method 2: Compile Statically

For C programs:

```dockerfile
RUN cd /build/custom && \
    gcc -static -o myprogram myprogram.c && \
    cp myprogram /build/initramfs/usr/bin/
```

### Method 3: Copy Binaries

```dockerfile
COPY --from=some-image /usr/bin/program /build/initramfs/usr/bin/
```

### Example: Add Python

```dockerfile
FROM builder-base AS python-builder

RUN cd /build && \
    wget https://www.python.org/ftp/python/3.11.0/Python-3.11.0.tgz && \
    tar xzf Python-3.11.0.tgz && \
    cd Python-3.11.0 && \
    ./configure --prefix=/usr --enable-optimizations && \
    make -j$(nproc) && \
    make install DESTDIR=/build/python-install

FROM initramfs-builder AS final-initramfs
COPY --from=python-builder /build/python-install /build/initramfs/
```

## Network Configuration

### Static IP Configuration

Add to `init.sh`:

```bash
# Configure network interface
ifconfig eth0 192.168.1.100 netmask 255.255.255.0 up
route add default gw 192.168.1.1

# Configure DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
```

### DHCP Configuration

Add to `init.sh`:

```bash
# Start DHCP client
udhcpc -i eth0 -s /etc/udhcpc/default.script
```

Create DHCP script at `/etc/udhcpc/default.script`:

```bash
#!/bin/sh

case "$1" in
    bound|renew)
        ip addr add $ip/$mask dev $interface
        [ -n "$router" ] && ip route add default via $router
        [ -n "$dns" ] && echo "nameserver $dns" > /etc/resolv.conf
        ;;
    deconfig)
        ip addr flush dev $interface
        ;;
esac
```

## Advanced Customization

### Multi-Architecture Support

Build for different architectures:

```dockerfile
ARG ARCH=x86_64

FROM debian:sid-slim AS builder-base
RUN apt-get update && \
    apt-get install -yq crossbuild-essential-${ARCH}
```

### Adding System Users

In `init.sh`:

```bash
# Create users and groups
echo "root:x:0:0:root:/root:/bin/sh" > /etc/passwd
echo "user:x:1000:1000:user:/home/user:/bin/sh" >> /etc/passwd
echo "root:x:0:" > /etc/group
echo "user:x:1000:" >> /etc/group

# Create home directories
mkdir -p /home/user
chown 1000:1000 /home/user
```

### Adding System Services

Create a simple service manager in `init.sh`:

```bash
# Service manager functions
start_service() {
    name=$1
    cmd=$2
    pidfile="/var/run/${name}.pid"
    
    if [ -f "$pidfile" ]; then
        echo "Service $name already running"
        return 1
    fi
    
    $cmd &
    echo $! > "$pidfile"
    echo "Started $name (PID $(cat $pidfile))"
}

stop_service() {
    name=$1
    pidfile="/var/run/${name}.pid"
    
    if [ ! -f "$pidfile" ]; then
        echo "Service $name not running"
        return 1
    fi
    
    kill $(cat "$pidfile")
    rm "$pidfile"
    echo "Stopped $name"
}

# Start services
start_service httpd "/usr/sbin/httpd -h /www"
start_service telnetd "/usr/sbin/telnetd"
```

### Adding Persistent Storage

Mount a persistent volume:

```bash
# In init.sh
mkdir -p /data
if [ -e /dev/sda1 ]; then
    mount /dev/sda1 /data
    echo "Mounted persistent storage"
fi
```

In QEMU:

```bash
# Create data disk
qemu-img create -f raw data.img 1G
mkfs.ext4 data.img

# Boot with data disk
qemu-system-x86_64 \
    -cdrom output.iso \
    -drive file=data.img,format=raw \
    -m 512M
```

### Custom Welcome Message

Create `/etc/motd`:

```bash
# In Dockerfile
RUN cat > /build/initramfs/etc/motd << 'EOF'
╔═══════════════════════════════════════╗
║   Welcome to Custom Linux System      ║
║   Built with handbuilt-linux               ║
╚═══════════════════════════════════════╝

For help: busybox --help
EOF
```

Show in `init.sh`:

```bash
[ -f /etc/motd ] && cat /etc/motd
```

## Testing Customizations

### Build and Test

```bash
# Build with customizations
make clean build

# Extract artifacts
make extract

# Test with QEMU
make qemu-nographic
```

### Quick Iteration

For rapid testing of init script changes:

```bash
# Extract current initramfs
mkdir -p /tmp/initramfs
cd /tmp/initramfs
gunzip -c ~/workspace/handbuilt-linux/initramfs | cpio -idmv

# Modify init script
nano init

# Rebuild initramfs
find . | cpio -H newc -o | gzip -9 > ~/workspace/handbuilt-linux/initramfs

# Test immediately
qemu-system-x86_64 \
    -kernel ~/workspace/handbuilt-linux/bzImage \
    -initrd ~/workspace/handbuilt-linux/initramfs \
    -nographic
```

## Best Practices

1. **Test incrementally** - Make small changes and test frequently
2. **Keep backups** - Save working configurations
3. **Document changes** - Comment your modifications
4. **Use version control** - Track configuration changes with Git
5. **Start simple** - Add complexity gradually
6. **Review logs** - Check kernel and system logs for errors

## Resources

- [Linux Kernel Documentation](https://www.kernel.org/doc/html/latest/)
- [BusyBox Documentation](https://busybox.net/docs/)
- [Syslinux Documentation](https://wiki.syslinux.org/)
- [Linux From Scratch](http://www.linuxfromscratch.org/)

## Need Help?

- Check existing issues on GitHub
- Open a new issue with details
- Include your configuration files
- Share error messages and logs
