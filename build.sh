#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="openwrt-builder"
PLATFORM="linux/amd64"
OUTPUT_DIR="$SCRIPT_DIR/output"

# List available distros and devices
available_options() {
  for distro_dir in "$SCRIPT_DIR"/config/*/; do
    distro=$(basename "$distro_dir")
    for cfg in "$distro_dir"*.config; do
      [ -f "$cfg" ] && echo "  $distro  $(basename "$cfg" .config)"
    done
  done
}

if [ $# -lt 2 ]; then
  echo "Usage: $0 <distro> <device>" >&2
  echo "" >&2
  echo "Available options:" >&2
  echo "  DISTRO  DEVICE" >&2
  available_options >&2
  exit 1
fi

DISTRO="$1"
DEVICE="$2"
CONFIG="config/${DISTRO}/${DEVICE}.config"
BUILD_SCRIPT="build-${DISTRO}.sh"

if [ ! -f "$SCRIPT_DIR/$CONFIG" ]; then
  echo "Error: Config not found: $CONFIG" >&2
  echo "" >&2
  echo "Available options:" >&2
  echo "  DISTRO  DEVICE" >&2
  available_options >&2
  exit 1
fi

if [ ! -f "$SCRIPT_DIR/scripts/$BUILD_SCRIPT" ]; then
  echo "Error: Build script not found: scripts/$BUILD_SCRIPT" >&2
  exit 1
fi

# Build Docker image if not exists
if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
  echo "Building Docker image..."
  docker build --platform "$PLATFORM" -t "$IMAGE_NAME" "$SCRIPT_DIR"
fi

mkdir -p "$OUTPUT_DIR"

docker run --rm \
  --platform "$PLATFORM" \
  -v "$SCRIPT_DIR/scripts:/scripts:ro" \
  -v "$SCRIPT_DIR/config:/config:ro" \
  -v "$SCRIPT_DIR/patch:/patch:ro" \
  -v openwrt-build:/build \
  -v "$OUTPUT_DIR:/output" \
  "$IMAGE_NAME" "/scripts/$BUILD_SCRIPT" "$CONFIG"
