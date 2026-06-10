# syntax=docker/dockerfile:1

ARG TARGET=tensorflow
ARG BASE_IMAGE=cuda-12.9-toolchain:ubuntu20.04
    
# Use the cuda-12.9-toolchain image for building TensorFlow (see common/linux_x86_64/ubuntu20.04/cuda-12.9-toolchain)
# This includes Python 3.12, LLVM, a virtual environment, and bazel.
FROM ${BASE_IMAGE} AS build

# Prepare to build and set any environmental flags that bazel might be difficult with
ENV CC_OPT_FLAGS="-Wno-gnu-offsetof-extensions -Wno-error -Wno-c23-extensions -Wno-macro-redefined" CPATH="${CUDA_HOME}/include:/usr/local/cuda-12.9/targets/x86_64-linux/include"

# Enable busting the cache and forcing a git refresh and new bazel build
ARG GIT_BUILD_NUMBER 0

# Initialize the TensorFlow repo
RUN mkdir -p /workspace/tensorflow
WORKDIR /workspace/tensorflow
RUN git init /workspace/tensorflow && git config --global --add safe.directory /workspace/tensorflow && \
    git remote add origin https://github.com/andersensam/tensorflow && \
    git -c protocol.version=2 fetch --no-tags --prune --no-recurse-submodules --depth=1 origin && \
    git checkout r2.19

# Enable busting the cache and focuing just a new bazel build
ARG BAZEL_BUILD_NUMBER 0

# Copy the CUDA config into the image
COPY tf_r2.19.1.4_ubuntu20.04.brc .tf_configure.bazelrc
RUN --mount=type=cache,target=/root/.cache/bazel,id=bazel-cache-r2.19.1.4-ubuntu20.04 \
    bazel build //tensorflow/tools/pip_package:wheel --repo_env=WHEEL_NAME=tensorflow --config=cuda --config=cuda_wheel \ 
        --copt=-Wno-gnu-offsetof-extensions --copt=-Wno-error --copt=-Wno-c23-extensions --verbose_failures \
        --copt=-Wno-macro-redefined

# Export the wheels
RUN --mount=type=cache,target=/root/.cache/bazel,id=bazel-cache-r2.19.1.4-ubuntu20.04 \
    cp /workspace/tensorflow/bazel-bin/tensorflow/tools/pip_package/wheel_house/*.whl /workspace && \
    mkdir -p /mnt/export && cp -rf /workspace/*.whl /mnt/export

FROM scratch AS tensorflow
COPY --from=build /mnt/export /wheels
