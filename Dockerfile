# syntax=docker/dockerfile:1.4
# =============================================================================
# Multi-stage Dockerfile for Building Custom Linux Distribution
# =============================================================================

FROM debian:sid-slim AS builder-base

ARG LINUX_VERSION=master
ARG BUSYBOX_VERSION=master
ARG SYSLINUX_VERSION=6.03
ARG DEBIAN_FRONTEND=noninteractive
ARG BUILD_JOBS=

LABEL maintainer="handbuilt-linux-project"
LABEL description="Custom Linux distribution builder"
LABEL version="1.0.0"

# Install build dependencies
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

WORKDIR /build

# -----------------------------------------------------------------------------
# Stage: source-downloader
# -----------------------------------------------------------------------------
FROM builder-base AS source-downloader

ARG LINUX_VERSION=master
ARG BUSYBOX_VERSION=master
ARG SYSLINUX_VERSION=6.03

RUN mkdir -p /build/initramfs && \
    mkdir -p /build/myiso/isolinux && \
    mkdir -p /build/sources && \
    mkdir -p /build/cache

WORKDIR /build/sources

# Clone Linux (shallow, branch/tag from ARG)
RUN --mount=type=cache,target=/build/cache \
    if [ ! -d /build/cache/linux ]; then \
        git clone --depth 1 --branch "${LINUX_VERSION}" https://github.com/torvalds/linux.git linux || \
        git clone --depth 1 https://github.com/torvalds/linux.git linux; \
        cp -r linux /build/cache/linux; \
    else \
        cp -r /build/cache/linux linux; \
    fi

# Clone BusyBox (shallow, branch/tag from ARG)
WORKDIR /build/sources
RUN --mount=type=cache,target=/build/cache \
    if [ ! -d /build/cache/busybox ]; then \
        git clone --depth 1 --branch "${BUSYBOX_VERSION}" https://git.busybox.net/busybox busybox || \
        git clone --depth 1 https://git.busybox.net/busybox busybox; \
        cp -r busybox /build/cache/busybox; \
    else \
        cp -r /build/cache/busybox busybox; \
    fi

# Download and extract Syslinux (tries multiple URLs)
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
# Stage: kernel-builder
# -----------------------------------------------------------------------------
FROM builder-base AS kernel-builder

ARG BUILD_JOBS
ARG LINUX_VERSION=master

COPY --from=source-downloader /build/sources/linux /build/linux
# If you have a linux.config in repo, it will be copied by the build context
COPY linux.config /build/linux/.config

WORKDIR /build/linux
RUN make olddefconfig && \
    make -j"${BUILD_JOBS:-$(nproc)}" && \
    (strip --strip-debug arch/x86/boot/bzImage 2>/dev/null || true)

# -----------------------------------------------------------------------------
# Stage: busybox-builder
# -----------------------------------------------------------------------------
FROM builder-base AS busybox-builder

ARG BUILD_JOBS
ARG BUSYBOX_VERSION=master

COPY --from=source-downloader /build/sources/busybox /build/busybox
COPY busybox.config /build/busybox/.config

WORKDIR /build/busybox

# Use a robust config step:
# - If a .config exists, prefer to run oldconfig (accept defaults automatically)
# - If oldconfig isn't available or fails, fall back to defconfig
RUN if [ -f .config ]; then \
        # Try non-interactive oldconfig (accept defaults); if not supported/fails, fall back
        (yes "" | make oldconfig) || make defconfig; \
    else \
        make defconfig; \
    fi && \
    make -j"${BUILD_JOBS:-$(nproc)}" && \
    make CONFIG_PREFIX=/build/initramfs install && \
    strip /build/initramfs/bin/busybox || true

# -----------------------------------------------------------------------------
# Stage: initramfs-builder
# -----------------------------------------------------------------------------
FROM builder-base AS initramfs-builder

COPY --from=busybox-builder /build/initramfs /build/initramfs
COPY init.sh /build/initramfs/init

RUN chmod +x /build/initramfs/init

WORKDIR /build/initramfs
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN find . -print0 | cpio --null --create --format=newc | gzip -9 > /build/initramfs.cpio.gz

# -----------------------------------------------------------------------------
# Stage: iso-builder
# -----------------------------------------------------------------------------
FROM builder-base AS iso-builder

ARG SYSLINUX_VERSION=6.03

COPY --from=source-downloader /build/sources/syslinux /build/syslinux
COPY --from=kernel-builder /build/linux/arch/x86/boot/bzImage /build/myiso/bzImage
COPY --from=initramfs-builder /build/initramfs.cpio.gz /build/myiso/initramfs

WORKDIR /build
RUN cp /build/syslinux/bios/core/isolinux.bin /build/myiso/isolinux/ && \
    cp /build/syslinux/bios/com32/elflink/ldlinux/ldlinux.c32 /build/myiso/isolinux/

COPY syslinux.cfg /build/myiso/isolinux/isolinux.cfg

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
# Stage: export-stage
# -----------------------------------------------------------------------------
FROM scratch AS export-stage

COPY --from=iso-builder /build/output.iso /output.iso
COPY --from=kernel-builder /build/linux/arch/x86/boot/bzImage /bzImage
COPY --from=initramfs-builder /build/initramfs.cpio.gz /initramfs

# -----------------------------------------------------------------------------
# Stage: runtime
# -----------------------------------------------------------------------------
FROM debian:sid-slim AS runtime

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -yq --no-install-recommends \
        qemu-system-x86 \
        qemu-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd -r distro && \
    useradd -r -g distro -d /distro -s /bin/bash distro && \
    mkdir -p /distro && \
    chown -R distro:distro /distro

COPY --from=iso-builder /build/output.iso /distro/output.iso
COPY --from=kernel-builder /build/linux/arch/x86/boot/bzImage /distro/bzImage
COPY --from=initramfs-builder /build/initramfs.cpio.gz /distro/initramfs

COPY --chown=distro:distro build.sh /distro/build.sh
RUN chmod +x /distro/build.sh

WORKDIR /distro
USER distro
ENV DISTRO_HOME=/distro
ENV PATH="${DISTRO_HOME}:${PATH}"

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD [ -f "/distro/output.iso" ] || exit 1

CMD ["/bin/bash"]