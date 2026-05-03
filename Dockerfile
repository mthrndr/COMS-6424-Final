FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    bison \
    flex \
    libreadline-dev \
    tcl-dev \
    libffi-dev \
    pkg-config \
    python3 \
    cmake \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Build Yosys
RUN git clone --recursive https://github.com/YosysHQ/yosys.git /tmp/yosys \
    && cd /tmp/yosys \
    && make -j$(nproc) \
    && make install \
    && rm -rf /tmp/yosys

# Build Slang
# Note that we need at least GCC 11, however ubuntu 24.04 should have 13+
RUN git clone https://github.com/MikePopoloski/slang.git /tmp/slang \
    && cd /tmp/slang \
    && cmake -B build -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build -j$(nproc) \
    && cmake --install build \
    && rm -rf /tmp/slang

# Build the Slang-Yosys Plugin
RUN git clone --recursive https://github.com/povik/yosys-slang.git /tmp/yosys-slang \
    && cd /tmp/yosys-slang \
    && make -j$(nproc) \
    && make install \
    && rm -rf /tmp/yosys-slang

WORKDIR /workspace
