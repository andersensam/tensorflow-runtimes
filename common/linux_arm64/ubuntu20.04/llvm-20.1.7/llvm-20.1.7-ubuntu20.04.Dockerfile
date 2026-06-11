# syntax=docker/dockerfile:1

ARG TARGET=llvm
ARG BASE_IMAGE=ubuntu:20.04

FROM --platform=linux/arm64 ${BASE_IMAGE} AS llvm-build
# Copy Python 3.12 into this image to build Ninja
RUN mkdir -p /opt/python3.12 && mkdir -p /tmp/staging
# Add the Python 3.12 install to this builder stage (build first with python-3.12-ubuntu20.04.Dockerfile)
COPY --from=python:3.12-ubuntu20.04-arm64 /python3.12 /opt/python3.12
ENV PATH="/opt/python3.12/bin:$PATH"
WORKDIR /tmp/staging
# Install dependencies for LLVM
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install build-essential make wget curl \
        git libssl-dev re2c ocaml libxml2-dev libedit-dev ocaml-findlib clang

# Build the minimum CMake version needed to build LLVM
RUN wget "https://github.com/Kitware/CMake/releases/download/v3.20.0/cmake-3.20.0.tar.gz" && \
    tar -xvf cmake-3.20.0.tar.gz && \
    cd cmake-3.20.0 && \
    ./bootstrap --prefix=/usr/local --parallel=$(nproc) && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf cmake-3.20.0*

# Build Ninja
RUN git clone --depth 1 --branch release https://github.com/ninja-build/ninja.git && \
    cd ninja && \
    python3.12 ./configure.py --bootstrap && \
    mv ninja /usr/local/bin && \
    cd .. && \
    rm -rf ninja

# Install NVCC, needed to enable the NVPTX target
# Grab the target version of LLVM and build it using the clang (LLVM 10)
# and ensure CUDA_HOME is defined.
# Do the compilation in one step to avoid caching the huge CUDA download and install, which we 
# need to do again later in the cuda-12.8-toolchain image build anyways.
RUN curl -o cuda-keyring_1.1-1_all.deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/sbsa/cuda-keyring_1.1-1_all.deb && \
    dpkg -i cuda-keyring_1.1-1_all.deb && \
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y cuda-libraries-dev-12-8 libcudnn9-dev-cuda-12 libnccl-dev ibverbs-utils \
        patchelf wget curl llvm build-essential git \
        cuda-nvvm-12-8 cuda-nvml-dev-12-8 cuda-nvrtc-dev-12-8 cuda-nvcc-12-8 libnccl2 \
        cuda-cupti-12-8 cuda-cupti-dev-12-8 nano pkg-config libhdf5-serial-dev && \
    git clone --depth 1 --branch llvmorg-20.1.7 https://github.com/llvm/llvm-project.git && \
    mkdir -p llvm-project/build && \
    cd llvm-project/build && \
    CUDA_HOME=/usr/local/cuda-12.8 CC=clang CXX=clang++ cmake ../llvm -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_ENABLE_PROJECTS="clang;lld;mlir;lld;openmp" \
        -DLLVM_TARGETS_TO_BUILD="AArch64;NVPTX" \
        -DLLVM_ENABLE_RUNTIMES="compiler-rt" \
        -DLLVM_INCLUDE_TESTS=OFF \
        -DLLVM_INCLUDE_EXAMPLES=OFF \
        -DLLVM_INCLUDE_BENCHMARKS=OFF \
        -DPython3_EXECUTABLE="/opt/python3.12/bin/python3.12" \
        -DCMAKE_INSTALL_PREFIX="/tmp/staging/llvm" && \
    ninja -C . && \
    ninja -C . install && \
    cd ../.. && \
    rm -rf llvm-project && \
    DEBIAN_FRONTEND=noninteractive apt-get remove -y cuda-libraries-dev-12-8 libcudnn9-dev-cuda-12 libnccl-dev ibverbs-utils \
        patchelf wget curl llvm build-essential git \
        cuda-nvvm-12-8 cuda-nvml-dev-12-8 cuda-nvrtc-dev-12-8 cuda-nvcc-12-8 libnccl2 \
        cuda-cupti-12-8 cuda-cupti-dev-12-8 nano pkg-config libhdf5-serial-dev && \
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y && \
    apt clean -y && \
    rm -rf /var/lib/apt/lists/*

FROM scratch AS llvm
COPY --from=llvm-build /tmp/staging/llvm /llvm