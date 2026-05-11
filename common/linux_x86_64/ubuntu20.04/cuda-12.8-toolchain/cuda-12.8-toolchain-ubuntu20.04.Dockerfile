# syntax=docker/dockerfile:1

ARG TARGET=cuda-12.8-toolchain
ARG BASE_IMAGE=ubuntu:20.04

FROM ${BASE_IMAGE} AS cuda-12.8-toolchain

# Copy Python 3.12 into this image (build first with python-3.12-ubuntu20.04.Dockerfile)
RUN mkdir -p /opt/python3.12 && mkdir -p /tmp/staging
COPY --from=python:3.12-ubuntu20.04 /python3.12 /opt/python3.12

# Copy LLVM 20.1.7 into this image (build first with llvm-20-ubuntu20.04.Dockerfile)
RUN mkdir -p /opt/llvm
COPY --from=llvm:20.1.7-ubuntu20.04 /llvm /opt/llvm

# Disable apt prompts
ENV DEBIAN_FRONTEND=noninteractive

# Enable the CUDA repository and install the required libraries for building TensorFlow
RUN apt-get update && apt-get install -y curl && \
    curl -o cuda-keyring_1.1-1_all.deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-keyring_1.1-1_all.deb && \
    dpkg -i cuda-keyring_1.1-1_all.deb && \
    apt-get update && apt-get install -y cuda-libraries-dev-12-8 libcudnn9-dev-cuda-12 libnccl-dev ibverbs-utils \
         patchelf wget curl llvm build-essential git \ 
         cuda-nvvm-12-8 cuda-nvml-dev-12-8 cuda-nvrtc-dev-12-8 cuda-nvcc-12-8 libnccl2 \
         cuda-cupti-12-8 cuda-cupti-dev-12-8 libxml2-dev libssl-dev xxd nano && \
    apt clean -y && \
    rm -rf /var/lib/apt/lists/*

# Setup the virtual environment for building
ENV VIRTUAL_ENV=/opt/venv
RUN /opt/python3.12/bin/python3.12 -m venv ${VIRTUAL_ENV}
ENV PATH="$VIRTUAL_ENV/bin:/opt/llvm/bin:$PATH"
ENV LLVM_HOME=/opt/llvm CUDA_HOME=/usr/local/cuda-12.8

# Upgrade pip and install uv
RUN /opt/venv/bin/python3.12 -m pip install --upgrade pip uv && \
    pip cache purge && \
    uv pip install setuptools wheel && \
    uv cache clean

# Install Bazelisk (Bazel wrapper)
RUN curl -o /usr/local/bin/bazel https://github.com/bazelbuild/bazelisk/releases/download/v1.29.0/bazelisk-linux-amd64 && \
    chmod +x /usr/local/bin/bazel && \
    /usr/local/bin/bazel version

# Create a workspace area
RUN mkdir -p /workspace
WORKDIR /workspace