# syntax=docker/dockerfile:1.4
# =============================================================================
# Multi-stage Dockerfile for Building Custom Linux Distribution
# =============================================================================
# This Dockerfile builds a minimal Linux distribution from scratch using:
# - Linux Kernel (from torvalds/linux)
# - BusyBox (minimal userspace utilities)
# - Syslinux (bootloader)
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Base builder with build dependencies
# -----------------------------------------------------------------------------
FROM debian:sid-slim AS builder-base

# Set build arguments for versioning and configuration
ARG LINUX_VERSION=master
ARG BUSYBOX_VERSION=master
ARG SYSLINUX_VERSION=6.04-pre1
ARG DEBIAN_FRONTEND=noninteractive
ARG BUILD_JOBS=

# Add metadata labels
LABEL maintainer="handbuilt-linux-project"
LABEL description="Custom Linux distribution builder"
LABEL version="1.0.0"

# Install build dependencies in a single layer with cleanup
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -yq --no-install-recommends \
        build-essential \
        bzip2 \
        git \
        make \
        gcc \
        libncurses-dev \
        flex \
        bison \
        bc \
        cpio \
        libelf-dev \
        libssl-dev \
        syslinux-common \
        dosfstools \
        genisoimage \
        wget \
        curl \
        ca-certificates \
        xz-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# -----------------------------------------------------------------------------
# Stage 2: Download and prepare sources
# -----------------------------------------------------------------------------
FROM builder-base AS source-downloader

ARG LINUX_VERSION=master
ARG BUSYBOX_VERSION=master
ARG SYSLINUX_VERSION=6.03

# Create directory structure
RUN mkdir -p /build/initramfs && \
    mkdir -p /build/myiso/isolinux && \
    mkdir -p /build/sources

# Download Linux kernel source
WORKDIR /build/sources
RUN --mount=type=cache,target=/build/cache \
    if [ ! -f /build/cache/linux/.git/config ]; then \
        git clone --depth 1 \
            https://github.com/torvalds/linux.git linux && \
        cp -r linux /build/cache/linux; \
    else \
        cp -r /build/cache/linux linux; \
    fi

# Download BusyBox source
WORKDIR /build/sources
RUN --mount=type=cache,target=/build/cache \
    if [ ! -f /build/cache/busybox/.git/config ]; then \
        git clone --depth 1 \
            https://git.busybox.net/busybox busybox && \
        cp -r busybox /build/cache/busybox; \
    else \
        cp -r /build/cache/busybox busybox; \
    fi

# Download and extract Syslinux
# Note: Using alternative download locations due to mirror availability
WORKDIR /build/sources
RUN set -eux; \
    tried=0; \
    for url in \
        "https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/syslinux-${SYSLINUX_VERSION}.tar.gz" \
        "https://www.kernel.org/pub/linux/utils/boot/syslinux/syslinux-${SYSLINUX_VERSION}.tar.gz" \
        "https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/Testing/${SYSLINUX_VERSION}/syslinux-${SYSLINUX_VERSION}.tar.gz"; do \
        echo "Trying $url"; \
        if curl -fsSL -o syslinux.tar.gz "$url"; then \
            tried=1; \
            break; \
        else \
            echo "Failed to download from $url"; \
        fi; \
    done; \
    if [ "$tried" -ne 1 ]; then \
        echo "ERROR: Unable to download syslinux ${SYSLINUX_VERSION}" >&2; \
        exit 22; \
    fi; \
    tar xzf syslinux.tar.gz && rm syslinux.tar.gz && mv "syslinux-${SYSLINUX_VERSION}" syslinux

# -----------------------------------------------------------------------------
# Stage 3: Build Linux kernel
# -----------------------------------------------------------------------------
FROM builder-base AS kernel-builder

ARG BUILD_JOBS

# Copy kernel source from downloader stage
COPY --from=source-downloader /build/sources/linux /build/linux

# Copy kernel configuration
COPY linux.config /build/linux/.config

# Build kernel
WORKDIR /build/linux
RUN make olddefconfig && \
    make -j"${BUILD_JOBS:-$(nproc)}" && \
    (strip --strip-debug arch/x86/boot/bzImage 2>/dev/null || true)

# -----------------------------------------------------------------------------
# Stage 4: Build BusyBox
# -----------------------------------------------------------------------------
FROM builder-base AS busybox-builder

ARG BUILD_JOBS

# Copy BusyBox source from downloader stage
COPY --from=source-downloader /build/sources/busybox /build/busybox

# Copy BusyBox configuration
COPY busybox.config /build/busybox/.config

# Build and install BusyBox
WORKDIR /build/busybox
RUN if [ -f .config ]; then \
        make olddefconfig || make defconfig; \
    else \
        make defconfig; \
    fi && \
    make -j"${BUILD_JOBS:-$(nproc)}" && \
    make CONFIG_PREFIX=/build/initramfs install && \
    strip /build/initramfs/bin/busybox

# -----------------------------------------------------------------------------
# Stage 5: Create initramfs
# -----------------------------------------------------------------------------
FROM builder-base AS initramfs-builder

# Copy BusyBox installation
COPY --from=busybox-builder /build/initramfs /build/initramfs

# Copy init script and make it executable
COPY init.sh /build/initramfs/init
RUN chmod +x /build/initramfs/init

# Create initramfs archive
WORKDIR /build/initramfs
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN find . -print0 | cpio --null --create --format=newc | gzip -9 > /build/initramfs.cpio.gz

# -----------------------------------------------------------------------------
# Stage 6: Create bootable ISO
# -----------------------------------------------------------------------------
FROM builder-base AS iso-builder

# Copy syslinux files
COPY --from=source-downloader /build/sources/syslinux /build/syslinux

# Copy kernel
COPY --from=kernel-builder /build/linux/arch/x86/boot/bzImage /build/myiso/bzImage

# Copy initramfs
COPY --from=initramfs-builder /build/initramfs.cpio.gz /build/myiso/initramfs

# Copy syslinux bootloader files
WORKDIR /build
RUN cp /build/syslinux/bios/core/isolinux.bin /build/myiso/isolinux/ && \
    cp /build/syslinux/bios/com32/elflink/ldlinux/ldlinux.c32 /build/myiso/isolinux/

# Copy bootloader configuration
COPY syslinux.cfg /build/myiso/isolinux/isolinux.cfg

# Create bootable ISO
WORKDIR /build
RUN mkisofs \
    -J \
    -R \
    -o output.iso \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    myiso

# -----------------------------------------------------------------------------
# Stage 7: Final minimal image with artifacts
# -----------------------------------------------------------------------------
FROM scratch AS export-stage

# Copy build artifacts
COPY --from=iso-builder /build/output.iso /output.iso
COPY --from=kernel-builder /build/linux/arch/x86/boot/bzImage /bzImage
COPY --from=initramfs-builder /build/initramfs.cpio.gz /initramfs

# -----------------------------------------------------------------------------
# Stage 8: Runtime image (default)
# -----------------------------------------------------------------------------
FROM debian:sid-slim AS runtime

# Install only runtime dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -yq --no-install-recommends \
        qemu-system-x86 \
        qemu-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user for better security
RUN groupadd -r distro && \
    useradd -r -g distro -d /distro -s /bin/bash distro && \
    mkdir -p /distro && \
    chown -R distro:distro /distro

# Copy build artifacts from iso-builder stage
COPY --from=iso-builder /build/output.iso /distro/output.iso
COPY --from=kernel-builder /build/linux/arch/x86/boot/bzImage /distro/bzImage
COPY --from=initramfs-builder /build/initramfs.cpio.gz /distro/initramfs

# Copy scripts
COPY --chown=distro:distro build.sh /distro/build.sh
RUN chmod +x /distro/build.sh

# Set working directory and user
WORKDIR /distro
USER distro

# Set environment variables
ENV DISTRO_HOME=/distro
ENV PATH="${DISTRO_HOME}:${PATH}"

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD [ -f "/distro/output.iso" ] || exit 1

# Default command
CMD ["/bin/bash"]
