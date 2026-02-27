#!/usr/bin/env bash
set -euo pipefail

# Dockerized build script for OpenWrt IPQ platform
# This script runs inside the Docker container
#
# Usage: build-ipq.sh <config-file>
# Example: build-ipq.sh config/ipq/qihoo-360v6.config

# Paths (inside container)
OUTPUT="/output"
WORKDIR="/build"
OPENWRT="${WORKDIR}/openwrt-ipq"

# Get config file from argument
if [ $# -lt 1 ]; then
    echo "Error: Configuration file required" >&2
    echo "Usage: $0 <config-file>" >&2
    echo "Example: $0 config/ipq/qihoo-360v6.config" >&2
    exit 1
fi

CONFIG_SRC="/$1"
[ -f "$CONFIG_SRC" ] || { echo "Error: Config not found: $CONFIG_SRC" >&2; exit 1; }

# 1) Fetch source
if [ ! -d "$OPENWRT/.git" ]; then
  git clone --branch main-nss --depth 1 https://github.com/qosmio/openwrt-ipq "$OPENWRT"
else
  git -C "$OPENWRT" fetch origin main-nss
  git -C "$OPENWRT" reset --hard origin/main-nss
fi

cd "$OPENWRT"
export SOURCE_DATE_EPOCH=$(git show -s --format=%ct HEAD)

# 2) Prep
rm -rf bin/targets

# Apply patches
PATCH_DIR="/patch"
if [ -d "$PATCH_DIR" ]; then
  while read -r patch_file; do
    if git apply --check "$patch_file" 2>/dev/null; then
      git apply "$patch_file"
      echo "Applied: $(basename "$patch_file")"
    elif git apply --reverse --check "$patch_file" 2>/dev/null; then
      echo "Already applied: $(basename "$patch_file")"
    else
      echo "ERROR: Failed to apply: $(basename "$patch_file")" >&2
      exit 1
    fi
  done < <(find "$PATCH_DIR" -name "*.patch" -type f | sort)
fi

# Feeds
[ -f feeds.conf ] || cp feeds.conf.default feeds.conf
./scripts/feeds update -a
./scripts/feeds install -a

grep -q "^src-git qosmio " feeds.conf || \
  echo "src-git qosmio https://github.com/qosmio/packages-extra" >> feeds.conf
./scripts/feeds update qosmio
./scripts/feeds install -p qosmio luci-mod-status-nss

# Config
cp "$CONFIG_SRC" .config
make defconfig
sed -i 's/^CONFIG_FEED_qosmio=.*/# CONFIG_FEED_qosmio is not set/' .config

# 3) Download and build
make download -j"$(nproc)"
make -j"$(nproc)" || make -j1 V=s

# 4) Package build outputs
TARGETS_DIR="${OPENWRT}/bin/targets"
if [ -d "$TARGETS_DIR" ]; then
    TARGET_DIR=$(find "$TARGETS_DIR" -mindepth 1 -maxdepth 1 -type d | head -n1)
    [ -n "$TARGET_DIR" ] && \
      tar -czf "${OUTPUT}/openwrt-$(date -d @"${SOURCE_DATE_EPOCH}" +%Y%m%d-%H%M%S 2>/dev/null || date -r "${SOURCE_DATE_EPOCH}" +%Y%m%d-%H%M%S).tar.gz" \
        -C "${TARGETS_DIR}" "$(basename "$TARGET_DIR")"
fi
