# syntax=docker/dockerfile:1

ARG TARGET=tensorflow-metadata
ARG BASE_IMAGE=cuda-12.8-toolchain:ubuntu22.04
    
# Use the CUDA 12.8 runtime image (for TensorFlow) (cuda-12.8-toolchain-ubuntu22.04.Dockerfile)
# to greatly speed up build time.
FROM ${BASE_IMAGE} AS tensorflow-metadata-build

WORKDIR /workspace

# Enable busting the cache and forcing a git refresh and new bazel build
ARG GIT_BUILD_NUMBER 0

# Fetch TensorFlow Metadata
RUN git clone --depth 1 --branch tensorflow_r2.21.0.1 https://github.com/andersensam/tensorflow-metadata
WORKDIR /workspace/tensorflow-metadata

# Enable busting the cache and forcing just a new bazel build
ARG BAZEL_BUILD_NUMBER 0

# Build the wheel
RUN python3.12 setup.py bdist_wheel && \
    mkdir -p /mnt/export && cp dist/*.whl /mnt/export

FROM scratch AS tensorflow-metadata
COPY --from=tensorflow-metadata-build /mnt/export /wheels