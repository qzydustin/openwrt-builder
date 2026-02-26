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

```bash
./build.sh <distro> <device>

# Example: Build for IPQ platform
./build.sh ipq qihoo-360v6
./build.sh ipq linksys-mx4300

# Run without arguments to see available options
./build.sh
```

The build script automatically builds the Docker image on first run.

## Build Process

1. Downloads OpenWrt source code from configured repository (if not present)
2. Applies patches from `patch/` directory
3. Compiles firmware using the specified configuration file
4. Outputs firmware archive to `output/openwrt-<timestamp>.tar.gz`

**Platform Support**: This project supports multiple platforms through platform-specific build scripts and config directories:
- `scripts/build-ipq.sh` + `config/ipq/`: Qualcomm IPQ platform (qosmio/openwrt-ipq)
- Additional platforms can be added as `scripts/build-<distro>.sh` + `config/<distro>/`

## Project Structure

```
openwrt-builder/
├── build.sh             # Entry point script
├── Dockerfile           # Docker image definition
├── scripts/             # Platform build scripts
│   └── build-ipq.sh     # IPQ platform build script
├── config/              # Device configurations
│   └── ipq/             # IPQ platform configs
│       ├── qihoo-360v6.config
│       └── linksys-mx4300.config
├── patch/               # Patches (optional)
│   └── *.patch
└── output/              # Build outputs (git-ignored)
    ├── openwrt-ipq/     # Source code and build cache
    └── openwrt-*.tar.gz # Firmware archives
```

## Device Configurations

Device configurations are organized by distro in the `config/` directory:

```bash
config/<distro>/<device>.config
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
rm -rf output/
docker build -t openwrt-builder .
```

**Note**: The OpenWrt source code is automatically downloaded during build. The local source directory is updated to the latest version from the configured repository. Uncommitted changes will be overwritten.
