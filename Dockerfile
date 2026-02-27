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
        libncurses-dev \
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

# Create build user
RUN groupadd -g 1001 builder && \
    useradd -u 1001 -g builder -m -s /bin/bash builder

WORKDIR /build
RUN chown builder:builder /build

USER builder
