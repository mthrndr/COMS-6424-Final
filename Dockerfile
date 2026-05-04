FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    autoconf \
    bison \
    build-essential \
    ca-certificates \
    cmake \
    device-tree-compiler \
    flex \
    git \
    help2man \
    libelf-dev \
    libffi-dev \
    libreadline-dev \
    pkg-config \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    tar \
    tcl-dev \
    vim \
    wget \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# We need a more modern version of verilator than the one that is in the repo
# for ubuntu 22.04
RUN git clone https://github.com/verilator/verilator && \
    cd verilator && \
    git checkout v5.020 && \
    autoconf && ./configure && \
    make -j$(nproc) && make install

# Download and extract core-v compiler from embecosm to /opt/corev as recommended
RUN wget https://buildbot.embecosm.com/job/corev-gcc-ubuntu2204/47/artifact/corev-openhw-gcc-ubuntu2204-20240530.tar.gz \
    && mkdir -p /opt/corev \
    && tar -xf corev-openhw-gcc-ubuntu2204-20240530.tar.gz -C /opt/corev --strip-components=1 \
    && rm corev-openhw-gcc-ubuntu2204-20240530.tar.gz

ENV PATH="/opt/corev/bin:${PATH}"

# Setup Venv
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Install core-v-verif requirements
COPY core-v-verif/bin/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir  -r /tmp/requirements.txt

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
