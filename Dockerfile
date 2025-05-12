# Dockerfile (必须全英文符号)
FROM --platform=$BUILDPLATFORM ubuntu:20.04

ARG ARCH
ARG TD_VERSION=latest
ENV DEBIAN_FRONTEND=noninteractive

# 1. 添加多架构支持和LLVM源
RUN dpkg --add-architecture armhf && \
    dpkg --add-architecture arm64 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        software-properties-common \
        wget && \
    wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - && \
    echo "deb http://apt.llvm.org/focal/ llvm-toolchain-focal-14 main" >> /etc/apt/sources.list

# 2. 安装跨平台工具链
RUN apt-get update && \
    apt-get install -y \
        crossbuild-essential-armhf \
        crossbuild-essential-arm64 \
        cmake git \
        clang-14 libc++-14-dev libc++abi-14-dev \
        openjdk-8-jdk:armhf \
        openjdk-8-jdk:arm64 \
        zlib1g-dev:armhf \
        zlib1g-dev:arm64 \
        libssl-dev:armhf \
        libssl-dev:arm64 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 3. 配置Java头文件
WORKDIR /usr/lib/jvm/java-8-openjdk-armhf/include
RUN wget https://raw.githubusercontent.com/xkaers/tdlib-build/main/jawt.h
WORKDIR /usr/lib/jvm/java-8-openjdk-arm64/include
RUN wget https://raw.githubusercontent.com/xkaers/tdlib-build/main/jawt.h

# 4. 构建TDLib
WORKDIR /build
RUN if [ "$TD_VERSION" = "latest" ]; then \
        git clone https://github.com/tdlib/td.git; \
    else \
        git clone --branch $TD_VERSION https://github.com/tdlib/td.git; \
    fi

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
    cmake --build . --target install -- -j$(nproc)

# 5. 打包输出
RUN cd td/example/java && \
    mkdir -p build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX:PATH=../../../tdlib \
          -DTd_DIR:PATH=$(readlink -e ../td/lib/cmake/Td) .. && \
    cmake --build . --target install -- -j$(nproc) && \
    cp -r org/ ../../tdlib && \
    cd ../../.. && \
    tar -czvf /output/tdlib-$ARCH.tar.gz tdlib/*
