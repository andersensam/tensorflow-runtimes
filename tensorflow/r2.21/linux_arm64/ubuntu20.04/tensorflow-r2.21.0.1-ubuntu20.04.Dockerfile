# syntax=docker/dockerfile:1

ARG TARGET=tensorflow
ARG BASE_IMAGE=cuda-12.8-toolchain:ubuntu20.04-arm64
    
# Use the TensorFlow Runtime image (tensorflow-runtime-ubuntu20.04.Dockerfile)
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

# Enable busting the cache and focuing just a new bazel build
ARG BAZEL_BUILD_NUMBER 0

# Copy the CUDA config into the image
COPY tf_r2.21.0.1_ubuntu20.04_arm64.brc .tf_configure.bazelrc
RUN --mount=type=cache,target=/root/.cache/bazel,id=bazel-cache-r2.21.0.1-ubuntu20.04 \
    bazel build //tensorflow/tools/pip_package:wheel --repo_env=WHEEL_NAME=tensorflow --config=cuda --config=cuda_wheel \
        --copt=-Wno-gnu-offsetof-extensions --copt=-Wno-error --copt=-Wno-c23-extensions --verbose_failures \
        --copt=-Wno-macro-redefined

# Export the wheels
RUN --mount=type=cache,target=/root/.cache/bazel,id=bazel-cache-r2.21.0.1-ubuntu20.04 \
    cp /workspace/tensorflow/bazel-bin/tensorflow/tools/pip_package/wheel_house/*.whl /workspace && \
    mkdir -p /mnt/export && cp -rf /workspace/*.whl /mnt/export

FROM scratch AS tensorflow
COPY --from=build /mnt/export /wheels