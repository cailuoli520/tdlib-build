# Dockerfile
FROM --platform=$BUILDPLATFORM ubuntu:20.04

ARG ARCH
ARG TD_VERSION=latest
ENV DEBIAN_FRONTEND=noninteractive

# 安装多架构支持
RUN dpkg --add-architecture armhf && \
    dpkg --add-architecture arm64

# 安装基础工具链
RUN apt-get update && apt-get install -y \
    crossbuild-essential-armhf \
    crossbuild-essential-arm64 \
    cmake git wget \
    clang-6.0 libc++-dev libc++abi-dev \
    openjdk-8-jdk-headless:armhf \
    openjdk-8-jdk-headless:arm64 \
    zlib1g-dev:armhf \
    zlib1g-dev:arm64 \
    libssl-dev:armhf \
    libssl-dev:arm64

WORKDIR /build

# 克隆代码库
RUN if [ "$TD_VERSION" = "latest" ]; then \
      git clone https://github.com/tdlib/td.git; \
    else \
      git clone --branch $TD_VERSION https://github.com/tdlib/td.git; \
    fi

# 配置构建环境
RUN cd td && \
    mkdir build && \
    cd build && \
    case "$ARCH" in \
      armv7) \
        export CC=arm-linux-gnueabihf-gcc \
        CXX=arm-linux-gnueabihf-g++ \
        JAVA_HOME=/usr/lib/jvm/java-8-openjdk-armhf \
        ;; \
      aarch64) \
        export CC=aarch64-linux-gnu-gcc \
        CXX=aarch64-linux-gnu-g++ \
        JAVA_HOME=/usr/lib/jvm/java-8-openjdk-arm64 \
        ;; \
    esac && \
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX:PATH=../example/java/td \
          -DTD_ENABLE_JNI=ON .. && \
    cmake --build . --target install

# 打包输出
RUN cd td/example/java && \
    mkdir -p build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX:PATH=../../../tdlib \
          -DTd_DIR:PATH=$(readlink -e ../td/lib/cmake/Td) .. && \
    cmake --build . --target install && \
    cp -r org/ ../../tdlib && \
    cd ../../.. && \
    tar -czvf /output/tdlib-$ARCH.tar.gz tdlib/*
