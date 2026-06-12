# syntax=docker/dockerfile:1

ARG TARGET=llvm
ARG BASE_IMAGE=ubuntu:20.04

FROM ${BASE_IMAGE} AS llvm-build
# Copy Python 3.12 into this image to build Ninja
RUN mkdir -p /opt/python3.12 && mkdir -p /tmp/staging
# Add the Python 3.12 install to this builder stage (build first with python-3.12-ubuntu20.04.Dockerfile)
COPY --from=python:3.12-ubuntu20.04 /python3.12 /opt/python3.12
ENV PATH="/opt/python3.12/bin:$PATH"
WORKDIR /tmp/staging
# Configure apt to keep downloaded packages for caching
RUN rm -f /etc/apt/apt.conf.d/docker-clean; \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

# Install dependencies for LLVM
RUN --mount=type=cache,id=apt-ubuntu20.04-x86_64,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lists-ubuntu20.04-x86_64,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && \
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
# need to do again later in the cuda-12.9-toolchain image build anyways.
RUN --mount=type=cache,id=apt-ubuntu20.04-x86_64,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lists-ubuntu20.04-x86_64,target=/var/lib/apt/lists,sharing=locked \
    curl -o cuda-keyring_1.1-1_all.deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-keyring_1.1-1_all.deb && \
    dpkg -i cuda-keyring_1.1-1_all.deb && \
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y cuda-libraries-dev-12-9 libcudnn9-dev-cuda-12 libnccl-dev ibverbs-utils \
        patchelf cuda-nvvm-12-9 cuda-nvml-dev-12-9 cuda-nvrtc-dev-12-9 cuda-nvcc-12-9 libnccl2 \
        cuda-cupti-12-9 cuda-cupti-dev-12-9 && \
    git clone --depth 1 --branch llvmorg-22.1.7 https://github.com/llvm/llvm-project.git && \
    mkdir -p llvm-project/build && \
    cd llvm-project/build && \
    CUDA_HOME=/usr/local/cuda-12.9 CC=clang CXX=clang++ cmake ../llvm -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_ENABLE_PROJECTS="clang;lld;mlir;lld;openmp" \
        -DLLVM_TARGETS_TO_BUILD="X86;NVPTX" \
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
    DEBIAN_FRONTEND=noninteractive apt-get remove -y cuda-libraries-dev-12-9 libcudnn9-dev-cuda-12 libnccl-dev ibverbs-utils \
        patchelf cuda-nvvm-12-9 cuda-nvml-dev-12-9 cuda-nvrtc-dev-12-9 cuda-nvcc-12-9 libnccl2 \
        cuda-cupti-12-9 cuda-cupti-dev-12-9 && \
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y

FROM scratch AS llvm
COPY --from=llvm-build /tmp/staging/llvm /llvm
