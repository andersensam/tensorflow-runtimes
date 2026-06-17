# syntax=docker/dockerfile:1

ARG TARGET=tensorflow
ARG BASE_IMAGE=cuda-12.8-toolchain:ubuntu20.04-arm64
    
# Use the cuda-12.8-toolchain image for building TensorFlow (see common/linux_arm64/ubuntu20.04/cuda-12.8-toolchain)
# This includes Python 3.12, LLVM, a virtual environment, and bazel.
FROM ${BASE_IMAGE} AS build

# Prepare to build and set any environmental flags that bazel might be difficult with
ENV CC_OPT_FLAGS="-Wno-gnu-offsetof-extensions -Wno-error -Wno-c23-extensions -Wno-macro-redefined" CPATH="${CUDA_HOME}/include:/usr/local/cuda-12.8/targets/x86_64-linux/include"

# Clone TensorFlow
RUN mkdir -p /workspace/tensorflow
WORKDIR /workspace/tensorflow

# Enable busting the cache and forcing a git refresh and new bazel build
ARG GIT_BUILD_NUMBER 0

# Initialize the TensorFlow repo
RUN git init /workspace/tensorflow && git config --global --add safe.directory /workspace/tensorflow && \
    git remote add origin https://github.com/andersensam/tensorflow && \
    git -c protocol.version=2 fetch --no-tags --prune --no-recurse-submodules --depth=1 origin && \
    git checkout r2.19

# Enable busting the cache and forcing just a new bazel build
ARG BAZEL_BUILD_NUMBER 0

# Copy the CUDA config into the image
COPY tf_r2.19.1.3_ubuntu20.04_arm64.brc .tf_configure.bazelrc
RUN --mount=type=cache,target=/root/.cache/bazel,id=bazel-cache-r2.19.1.3-ubuntu20.04 \
    bazel clean --expunge
