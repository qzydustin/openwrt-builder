# openwrt-builder

Build OpenWrt firmware using Docker containers without installing build dependencies on the host.

## Requirements

- Docker installed and running
- At least 20GB free disk space
- 4GB+ RAM recommended

## Quick Start

### 1. Build Docker Image

```bash
docker build -t openwrt-builder .
```

### 2. Run Build

Specify the configuration file as an argument to the build script:

```bash
# Example: Build for IPQ platform with a specific config
docker run --rm \
  -v "$(pwd):/builder" \
  --user "$(id -u):$(id -g)" \
  openwrt-builder /builder/build-ipq.sh config/<device>.config

# For other platforms, use the corresponding build script
# docker run --rm \
#   -v "$(pwd):/builder" \
#   --user "$(id -u):$(id -g)" \
#   openwrt-builder /builder/build-<platform>.sh config/<device>.config
```

**Note**: The `--user` flag ensures files created in the container are owned by your host user, avoiding permission issues.

## Build Process

1. Downloads OpenWrt source code from configured repository (if not present)
2. Applies patches from `patch/` directory
3. Compiles firmware using the specified configuration file
4. Outputs firmware archive: `openwrt-<timestamp>.tar.gz`

**Platform Support**: This project supports multiple platforms through platform-specific build scripts:
- `build-ipq.sh`: IPQ platform
- Additional platform scripts can be added as `build-<platform>.sh`

Specify the build script when running the container (see Run Build section above).

## Project Structure

```
openwrt-builder/
├── build-ipq.sh         # IPQ platform build script
├── build-*.sh           # Other platform build scripts (future)
├── Dockerfile           # Docker image definition
├── config/              # Device configurations
│   ├── qihoo-360v6.config
│   └── linksys-mx4300.config
└── patch/               # Patches (optional)
    └── *.patch
```

## Device Configurations

Device configurations are stored in the `config/` directory. Specify the configuration file as an argument when running the build script:

```bash
/builder/build-ipq.sh config/<device>.config
```

## Environment Variables

Automatically set for reproducible builds:
- `SOURCE_DATE_EPOCH`: From Git commit timestamp
- `TZ=UTC`: Unified timezone
- `KBUILD_BUILD_USER=builder`: Kernel build user
- `KBUILD_BUILD_HOST=OpenWrt-Builder`: Kernel build host

The container runs as non-root user (builder, UID 1000) for security.

## Troubleshooting

**Clean rebuild**:
```bash
docker rmi openwrt-builder
# Remove local OpenWrt source directory if needed (auto-downloaded, not in repo)
docker build -t openwrt-builder .
```

**Note**: The OpenWrt source code is automatically downloaded during build. The local source directory is updated to the latest version from the configured repository. Uncommitted changes will be overwritten.
