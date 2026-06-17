# syntax=docker/dockerfile:1

ARG TARGET=tensorflow
ARG BASE_IMAGE=cuda-12.8-toolchain:ubuntu20.04-arm64
    
# Use the CUDA 12.8 runtime image (for TensorFlow) (cuda-12.8-toolchain-ubuntu20.04.Dockerfile)
# to greatly speed up build time.
FROM ${BASE_IMAGE} AS build

WORKDIR /workspace/tensorflow

# Enable busting the cache and forcing a git refresh and new bazel build
ARG GIT_BUILD_NUMBER 0

# Initialize the TensorFlow repo
RUN git init /workspace/tensorflow && git config --global --add safe.directory /workspace/tensorflow && \
    git remote add origin https://github.com/andersensam/tensorflow && \
    git -c protocol.version=2 fetch --no-tags --prune --no-recurse-submodules --depth=1 origin && \
    git checkout r2.21

# Enable busting the cache and forcing just a new bazel build
ARG BAZEL_BUILD_NUMBER 0

# Copy the CUDA config into the image
COPY tf_r2.21.0.2_ubuntu20.04_arm64.brc .tf_configure.bazelrc
ENV HERMETIC_PYTHON_VERSION=3.12
RUN --mount=type=cache,target=/root/.cache/bazel,id=bazel-cache-r2.21.0.2-ubuntu20.04-arm64 \
    bazel clean --expunge
