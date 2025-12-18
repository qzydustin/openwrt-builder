FROM ubuntu:24.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV KBUILD_BUILD_USER=builder
ENV KBUILD_BUILD_HOST=OpenWrt-Builder

# Install all build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        clang \
        flex \
        bison \
        g++ \
        gawk \
        gcc-multilib \
        g++-multilib \
        gettext \
        git \
        libncurses5-dev \
        libssl-dev \
        python3-setuptools \
        rsync \
        swig \
        unzip \
        zlib1g-dev \
        file \
        wget \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /builder

# Copy all build scripts
COPY build-*.sh /builder/
RUN chmod +x /builder/build-*.sh && \
    chown -R 1000:1000 /builder/build-*.sh

# Switch to non-root user (UID 1000, default in Ubuntu)
USER 1000
