#!/usr/bin/env bash
set -euo pipefail

# Dockerized build script for OpenWrt IPQ platform
# This script runs inside the Docker container
#
# Usage: build-ipq.sh <config-file>
# Example: build-ipq.sh config/ipq/qihoo-360v6.config

# Paths (inside container)
INPUT="/input"
OUTPUT="/output"
OPENWRT="${OUTPUT}/openwrt-ipq"

# Get config file from argument
if [ $# -lt 1 ]; then
    echo "Error: Configuration file required" >&2
    echo "Usage: $0 <config-file>" >&2
    echo "Example: $0 config/ipq/qihoo-360v6.config" >&2
    exit 1
fi

CONFIG_SRC="${INPUT}/$1"
[ -f "$CONFIG_SRC" ] || { echo "Error: Configuration file not found: $CONFIG_SRC" >&2; exit 1; }

# 1) Fetch source (IPQ platform: qosmio/openwrt-ipq, branch main-nss)
if [ ! -d "$OPENWRT/.git" ]; then
  git clone --branch main-nss --depth 1 https://github.com/qosmio/openwrt-ipq "$OPENWRT"
else
  cd "$OPENWRT"
  git fetch origin main-nss
  git reset --hard origin/main-nss
  cd "$OUTPUT"
fi

# Set SOURCE_DATE_EPOCH from git commit timestamp for reproducible builds
cd "$OPENWRT"
main_epoch=$(git show -s --format=%ct HEAD)
export SOURCE_DATE_EPOCH=$main_epoch

# 2) Prep
# Clean previous build outputs
if [ -d "bin/targets" ]; then
  rm -rf bin/targets/*
fi

# Apply patches
PATCH_DIR="${INPUT}/patch"
if [ -d "$PATCH_DIR" ]; then
  find "$PATCH_DIR" -name "*.patch" -type f | sort | while read -r patch_file; do
    if git apply --check "$patch_file" 2>/dev/null; then
      git apply "$patch_file"
      echo "Applied: $(basename "$patch_file")"
    elif git apply --reverse --check "$patch_file" 2>/dev/null; then
      echo "Already applied: $(basename "$patch_file")"
    else
      echo "ERROR: Failed to apply: $(basename "$patch_file")" >&2
      exit 1
    fi
  done
fi

# Feeds setup
[ -f feeds.conf ] || cp feeds.conf.default feeds.conf

# Official feeds: update and install all
./scripts/feeds update -a
./scripts/feeds install -a

# Third-party feed: install only specific package
grep -q "^src-git qosmio " feeds.conf || \
  echo "src-git qosmio https://github.com/qosmio/packages-extra" >> feeds.conf

./scripts/feeds update qosmio
./scripts/feeds install -p qosmio luci-mod-status-nss

# Config
cp "$CONFIG_SRC" .config
make defconfig
sed -i 's/^CONFIG_FEED_qosmio=.*/# CONFIG_FEED_qosmio is not set/' .config
# Set kernel build user and host from environment variables
if [ -n "${KBUILD_BUILD_USER:-}" ]; then
  grep -q '^CONFIG_KERNEL_BUILD_USER=' .config && \
    sed -i "s/^CONFIG_KERNEL_BUILD_USER=.*/CONFIG_KERNEL_BUILD_USER=\"${KBUILD_BUILD_USER}\"/" .config || \
    echo "CONFIG_KERNEL_BUILD_USER=\"${KBUILD_BUILD_USER}\"" >> .config
fi
if [ -n "${KBUILD_BUILD_HOST:-}" ]; then
  grep -q '^CONFIG_KERNEL_BUILD_DOMAIN=' .config && \
    sed -i "s/^CONFIG_KERNEL_BUILD_DOMAIN=.*/CONFIG_KERNEL_BUILD_DOMAIN=\"${KBUILD_BUILD_HOST}\"/" .config || \
    echo "CONFIG_KERNEL_BUILD_DOMAIN=\"${KBUILD_BUILD_HOST}\"" >> .config
fi

# 3) Download and build
make download -j"$(nproc)"

# Build
make -j"$(nproc)" || {
  echo "Parallel build failed, retrying single-threaded..."
  make -j1 V=s
}

# 4) Package build outputs
TARGETS_DIR="${OPENWRT}/bin/targets"
if [ -d "$TARGETS_DIR" ]; then
    TARGET_DIR=$(find "$TARGETS_DIR" -mindepth 1 -maxdepth 1 -type d | head -n1)
    [ -n "$TARGET_DIR" ] && \
      tar -czf "${OUTPUT}/openwrt-$(date -d @"${SOURCE_DATE_EPOCH}" +%Y%m%d-%H%M%S 2>/dev/null || date -r "${SOURCE_DATE_EPOCH}" +%Y%m%d-%H%M%S).tar.gz" \
        -C "${TARGETS_DIR}" "$(basename "$TARGET_DIR")"
fi
