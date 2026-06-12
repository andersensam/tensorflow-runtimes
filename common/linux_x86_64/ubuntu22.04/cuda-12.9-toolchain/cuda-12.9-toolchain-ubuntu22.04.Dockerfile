# syntax=docker/dockerfile:1

ARG TARGET=cuda-12.9-toolchain
ARG BASE_IMAGE=ubuntu:22.04

FROM ${BASE_IMAGE} AS cuda-12.9-toolchain

# Copy Python 3.12 into this image (build first with python-3.12-ubuntu22.04.Dockerfile)
RUN mkdir -p /opt/python3.12 && mkdir -p /tmp/staging
COPY --from=python:3.12-ubuntu22.04 /python3.12 /opt/python3.12

# Disable apt prompts
ENV DEBIAN_FRONTEND=noninteractive

# Configure apt to keep downloaded packages for caching
RUN rm -f /etc/apt/apt.conf.d/docker-clean; \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

# Download LLVM 22.1.7 and extract to /opt/llvm
RUN --mount=type=cache,id=apt-ubuntu22.04-x86_64,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lists-ubuntu22.04-x86_64,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && \
    apt-get install -y curl xz-utils && \
    curl -o LLVM-22.1.7.tar.xz https://storage.googleapis.com/axlearn-wheels/llvm/LLVM-22.1.7-Linux-X64.tar.xz && \
    tar -xvf LLVM-22.1.7.tar.xz && \
    mkdir -p /opt/llvm && \
    mv LLVM-22.1.7-Linux-X64/* /opt/llvm/ && \
    rm -rf LLVM-22.1.7*

# Enable the CUDA repository and install the required libraries for building TensorFlow
RUN --mount=type=cache,id=apt-ubuntu22.04-x86_64,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lists-ubuntu22.04-x86_64,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y curl && \
    curl -o cuda-keyring_1.1-1_all.deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb && \
    dpkg -i cuda-keyring_1.1-1_all.deb && \
    apt-get update && apt-get install -y cuda-libraries-dev-12-9 libcudnn9-dev-cuda-12 libnccl-dev ibverbs-utils \
         patchelf wget curl llvm build-essential git \
         cuda-nvvm-12-9 cuda-nvml-dev-12-9 cuda-nvrtc-dev-12-9 cuda-nvcc-12-9 libnccl2 \
         cuda-cupti-12-9 cuda-cupti-dev-12-9 libxml2-dev libssl-dev xxd nano

# Setup the virtual environment for building
ENV VIRTUAL_ENV=/opt/venv
RUN /opt/python3.12/bin/python3.12 -m venv ${VIRTUAL_ENV}
ENV PATH="$VIRTUAL_ENV/bin:/opt/llvm/bin:$PATH"
ENV LLVM_HOME=/opt/llvm CUDA_HOME=/usr/local/cuda-12.9

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