#!/bin/sh

# =============================================================================
# Init Script for Custom Linux Distribution
# =============================================================================
# This is the first process that runs after the kernel boots (PID 1)
# It sets up the basic system environment and drops to a shell
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
HOSTNAME="${HOSTNAME:-handbuilt-linux}"
ROOT_HOME="${HOME:-/root}"
RESCUE_SHELL="/bin/sh"

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

# Print colored output (if supported)
print_info() {
    echo "[INFO] $*"
}

print_error() {
    echo "[ERROR] $*" >&2
}

print_success() {
    echo "[OK] $*"
}

# Error handler
panic() {
    print_error "PANIC: $*"
    print_error "Dropping to rescue shell..."
    exec ${RESCUE_SHELL}
}

# -----------------------------------------------------------------------------
# System Initialization
# -----------------------------------------------------------------------------

print_info "Starting init process (PID $$)..."

# Create essential directories if they don't exist
print_info "Creating essential directories..."
mkdir -p /proc /sys /dev /tmp /run /var /mnt /root /home 2>/dev/null || true
print_success "Directories created"

# Mount essential filesystems
print_info "Mounting essential filesystems..."

mount -t proc none /proc || panic "Failed to mount /proc"
print_success "Mounted /proc"

mount -t sysfs none /sys || panic "Failed to mount /sys"
print_success "Mounted /sys"

mount -t devtmpfs none /dev 2>/dev/null || {
    print_info "devtmpfs not available, using tmpfs for /dev"
    mount -t tmpfs -o mode=0755 none /dev || panic "Failed to mount /dev"
}
print_success "Mounted /dev"

mount -t tmpfs -o mode=1777,strictatime,nodev,nosuid tmpfs /tmp || \
    panic "Failed to mount /tmp"
print_success "Mounted /tmp"

mount -t tmpfs -o mode=0755,nodev,nosuid tmpfs /run || \
    panic "Failed to mount /run"
print_success "Mounted /run"

# Create device nodes if using tmpfs for /dev
if ! mountpoint -q /proc/sys/kernel >/dev/null 2>&1; then
    print_info "Creating essential device nodes..."
    [ -c /dev/null ] || mknod -m 666 /dev/null c 1 3
    [ -c /dev/zero ] || mknod -m 666 /dev/zero c 1 5
    [ -c /dev/random ] || mknod -m 666 /dev/random c 1 8
    [ -c /dev/urandom ] || mknod -m 666 /dev/urandom c 1 9
    [ -c /dev/console ] || mknod -m 600 /dev/console c 5 1
    [ -c /dev/tty ] || mknod -m 666 /dev/tty c 5 0
    print_success "Device nodes created"
fi

# Populate /dev with mdev
if command -v mdev >/dev/null 2>&1; then
    print_info "Populating /dev with mdev..."
    mdev -s || print_error "mdev failed (non-fatal)"
    print_success "Device population complete"

    # Start mdev as hotplug helper if possible
    if [ -f /proc/sys/kernel/hotplug ]; then
        echo /sbin/mdev > /proc/sys/kernel/hotplug
        print_success "mdev hotplug helper enabled"
    fi
else
    print_error "mdev not found, device hotplug unavailable"
fi

# Create standard device links
print_info "Creating standard device links..."
ln -sf /proc/self/fd /dev/fd 2>/dev/null || true
ln -sf /proc/self/fd/0 /dev/stdin 2>/dev/null || true
ln -sf /proc/self/fd/1 /dev/stdout 2>/dev/null || true
ln -sf /proc/self/fd/2 /dev/stderr 2>/dev/null || true
print_success "Device links created"

# Set hostname
print_info "Setting hostname to '${HOSTNAME}'..."
hostname "${HOSTNAME}" || print_error "Failed to set hostname (non-fatal)"
echo "${HOSTNAME}" > /proc/sys/kernel/hostname 2>/dev/null || true
print_success "Hostname set"

# Create /etc directory and basic files
print_info "Setting up /etc..."
mkdir -p /etc
cat > /etc/hostname << EOF
${HOSTNAME}
EOF

cat > /etc/hosts << EOF
127.0.0.1   localhost
127.0.1.1   ${HOSTNAME}
::1         localhost ip6-localhost ip6-loopback
EOF

cat > /etc/fstab << EOF
# <file system> <mount point> <type> <options> <dump> <pass>
proc            /proc         proc   defaults          0      0
sysfs           /sys          sysfs  defaults          0      0
devtmpfs        /dev          devtmpfs defaults        0      0
tmpfs           /tmp          tmpfs  mode=1777         0      0
tmpfs           /run          tmpfs  mode=0755         0      0
EOF

print_success "/etc configuration complete"

# Set up environment
print_info "Setting up environment..."
export HOME="${ROOT_HOME}"
export USER="root"
export LOGNAME="root"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export SHELL="${RESCUE_SHELL}"
export TERM="${TERM:-linux}"
export PS1='\[\033[1;32m\]\u@\h\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]\$ '

# Create .profile if it doesn't exist
cat > "${ROOT_HOME}/.profile" << 'EOF'
# Environment setup for root user
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PS1='\[\033[1;32m\]\u@\h\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]\$ '
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
EOF

print_success "Environment configured"

# Show system information
print_info "System initialization complete!"
echo ""
echo "=================================================="
echo "  Custom Linux Distribution"
echo "=================================================="
echo "Hostname: ${HOSTNAME}"
echo "Kernel:   $(uname -r)"
echo "Init PID: $$"
echo "Shell:    ${RESCUE_SHELL}"
echo "=================================================="
echo ""

# Print welcome message
cat << 'EOF'
Welcome to the custom Linux distribution!

This is a minimal Linux system built from scratch with:
- Linux Kernel
- BusyBox (minimal userspace utilities)
- Custom init system

For help, type: busybox --help
To see all available commands, type: busybox --list

EOF

# Drop to shell
print_info "Starting interactive shell..."
cd "${ROOT_HOME}"

# Use exec to replace init with shell (PID 1 will be the shell)
exec ${RESCUE_SHELL}
