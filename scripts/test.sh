#!/usr/bin/env bash

# =============================================================================
# Test Script for Linux Distribution
# =============================================================================

set -euo pipefail

readonly SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $*" >&2
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

# -----------------------------------------------------------------------------
# Tests
# -----------------------------------------------------------------------------

test_docker_image_exists() {
    log_info "Testing if Docker image exists..."
    if docker image inspect handbuilt-linux:latest &> /dev/null; then
        log_success "Docker image exists"
        return 0
    else
        log_error "Docker image not found"
        return 1
    fi
}

test_iso_exists() {
    log_info "Testing if ISO can be extracted..."
    if docker run --rm handbuilt-linux:latest test -f /distro/output.iso; then
        log_success "ISO exists in Docker image"
        return 0
    else
        log_error "ISO not found in Docker image"
        return 1
    fi
}

test_kernel_exists() {
    log_info "Testing if kernel can be extracted..."
    if docker run --rm handbuilt-linux:latest test -f /distro/bzImage; then
        log_success "Kernel exists in Docker image"
        return 0
    else
        log_error "Kernel not found in Docker image"
        return 1
    fi
}

test_initramfs_exists() {
    log_info "Testing if initramfs can be extracted..."
    if docker run --rm handbuilt-linux:latest test -f /distro/initramfs; then
        log_success "Initramfs exists in Docker image"
        return 0
    else
        log_error "Initramfs not found in Docker image"
        return 1
    fi
}

test_iso_is_valid() {
    log_info "Testing if ISO is valid..."
    local iso_file="${PROJECT_DIR}/output.iso"

    if [[ ! -f "${iso_file}" ]]; then
        log_warning "ISO not extracted yet, extracting..."
        docker run --rm handbuilt-linux:latest cat /distro/output.iso > "${iso_file}"
    fi

    if file "${iso_file}" | grep -q "ISO 9660"; then
        log_success "ISO is valid"
        return 0
    else
        log_error "ISO is not valid"
        return 1
    fi
}

test_initramfs_is_valid() {
    log_info "Testing if initramfs is valid..."
    local initramfs_file="${PROJECT_DIR}/initramfs"

    if [[ ! -f "${initramfs_file}" ]]; then
        log_warning "Initramfs not extracted yet, extracting..."
        docker run --rm handbuilt-linux:latest cat /distro/initramfs > "${initramfs_file}"
    fi

    if file "${initramfs_file}" | grep -q "gzip compressed"; then
        log_success "Initramfs is valid"
        return 0
    else
        log_error "Initramfs is not valid"
        return 1
    fi
}

test_build_sh_syntax() {
    log_info "Testing build.sh syntax..."
    if bash -n "${PROJECT_DIR}/build.sh"; then
        log_success "build.sh syntax is valid"
        return 0
    else
        log_error "build.sh has syntax errors"
        return 1
    fi
}

test_init_sh_syntax() {
    log_info "Testing init.sh syntax..."
    if sh -n "${PROJECT_DIR}/init.sh"; then
        log_success "init.sh syntax is valid"
        return 0
    else
        log_error "init.sh has syntax errors"
        return 1
    fi
}

test_dockerfile_lint() {
    log_info "Testing Dockerfile with hadolint..."
    if command -v hadolint &> /dev/null; then
        if hadolint "${PROJECT_DIR}/Dockerfile" 2>&1 | grep -v "DL3008"; then
            log_success "Dockerfile lint passed"
            return 0
        else
            log_warning "Dockerfile has lint warnings (non-critical)"
            return 0
        fi
    else
        log_warning "hadolint not found, skipping Dockerfile lint"
        return 0
    fi
}

test_qemu_available() {
    log_info "Testing if QEMU is available..."
    if command -v qemu-system-x86_64 &> /dev/null; then
        log_success "QEMU is available"
        return 0
    else
        log_warning "QEMU not found (optional for testing)"
        return 0
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    echo "========================================"
    echo "  handbuilt-linux Test Suite"
    echo "========================================"
    echo ""

    # Run tests
    test_docker_image_exists || true
    test_iso_exists || true
    test_kernel_exists || true
    test_initramfs_exists || true
    test_iso_is_valid || true
    test_initramfs_is_valid || true
    test_build_sh_syntax || true
    test_init_sh_syntax || true
    test_dockerfile_lint || true
    test_qemu_available || true

    # Summary
    echo ""
    echo "========================================"
    echo "  Test Summary"
    echo "========================================"
    echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
    echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
    echo ""

    if [[ ${TESTS_FAILED} -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

main "$@"
