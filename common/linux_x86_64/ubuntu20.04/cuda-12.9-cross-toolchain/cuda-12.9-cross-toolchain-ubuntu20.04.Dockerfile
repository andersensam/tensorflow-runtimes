# syntax=docker/dockerfile:1

ARG TARGET=cuda-12.9-cross-toolchain
ARG BASE_IMAGE=ubuntu:20.04

FROM ${BASE_IMAGE} AS cuda-12.9-cross-toolchain

# Copy Python 3.12 into this image (build first with python-3.12-ubuntu20.04.Dockerfile)
RUN mkdir -p /opt/python3.12 && mkdir -p /tmp/staging
COPY --from=python:3.12-ubuntu20.04 /python3.12 /opt/python3.12

# Copy LLVM 22.1.7 into this image (build first with llvm-22.1.7-ubuntu20.04.Dockerfile)
RUN mkdir -p /opt/llvm
COPY --from=llvm:22.1.7-multiarch-ubuntu20.04 /llvm /opt/llvm

# Disable apt prompts
ENV DEBIAN_FRONTEND=noninteractive

# Configure apt to keep downloaded packages for caching
RUN rm -f /etc/apt/apt.conf.d/docker-clean; \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

# Enable the CUDA repository and install the required libraries for building TensorFlow
RUN --mount=type=cache,id=apt-ubuntu20.04-x86_64,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lists-ubuntu20.04-x86_64,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y curl && \
    curl -o cuda-keyring_1.1-1_all.deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-keyring_1.1-1_all.deb && \
    dpkg -i cuda-keyring_1.1-1_all.deb && \
    apt-get update && apt-get install -y cuda-libraries-dev-12-9 libcudnn9-dev-cuda-12 libnccl-dev ibverbs-utils \
         patchelf wget curl llvm build-essential git \
         cuda-nvvm-12-9 cuda-nvml-dev-12-9 cuda-nvrtc-dev-12-9 cuda-nvcc-12-9 libnccl2 \
         cuda-cupti-12-9 cuda-cupti-dev-12-9 libxml2-dev libssl-dev xxd nano \
         gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu

# Setup the virtual environment for building
ENV VIRTUAL_ENV=/opt/venv
RUN /opt/python3.12/bin/python3.12 -m venv ${VIRTUAL_ENV}
ENV PATH="$VIRTUAL_ENV/bin:/opt/llvm/bin:$PATH"
ENV LLVM_HOME=/opt/llvm CUDA_HOME=/usr/local/cuda-12.9

# Setup symlinks to trick Bazel's cross_compile_toolchain_suite.
# The toolchain hardcodes its compiler and header paths to /usr/lib/llvm-18 and /dt9 /dt10.
# By symlinking our custom LLVM 22 installation (in /opt/llvm) to /usr/lib/llvm-18,
# and our clang 22 resource directory to clang 18, we seamlessly override the
# hardcoded paths without needing to patch dozens of build files across TensorFlow!
RUN ln -s /opt/llvm /usr/lib/llvm-18 && \
    ln -s / /dt9 && \
    ln -s /usr/aarch64-linux-gnu /dt10 && \
    mkdir -p /opt/llvm/lib/clang && \
    ln -s /opt/llvm/lib/clang/22 /opt/llvm/lib/clang/18

# Upgrade pip and install uv
RUN /opt/venv/bin/python3.12 -m pip install --upgrade pip uv && \
    pip cache purge && \
    uv pip install setuptools wheel && \
    uv cache clean

# Install Bazelisk (Bazel wrapper)
RUN curl -o /usr/local/bin/bazel https://storage.googleapis.com/axlearn-wheels/bazelisk/v1.29.0/bazelisk-linux-amd64 && \
    chmod +x /usr/local/bin/bazel && \
    /usr/local/bin/bazel version

# Create a workspace area
RUN mkdir -p /workspace
WORKDIR /workspace