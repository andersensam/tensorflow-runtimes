# syntax=docker/dockerfile:1

ARG TARGET=tensorflow-io
ARG BASE_IMAGE=cuda-12.8-toolchain:ubuntu22.04

# Use the cuda-12.8-toolchain image for building TensorFlow I/O (see common/linux_x86_64/ubuntu22.04/cuda-12.8-toolchain)
# This includes Python 3.12, LLVM, a virtual environment, and bazel.
# Most notably: this was the same image used to build TensorFlow itself.
FROM ${BASE_IMAGE} AS tensorflow-io-build

WORKDIR /workspace

# Enable busting the cache and forcing a git refresh and new bazel build
ARG GIT_BUILD_NUMBER 0

# Clone TensorFlow I/O and install the Ubuntu 22.04 wheel for TensorFlow 2.19.1.3 (after resolving deps with regular 2.19.1)
RUN git clone --depth 1 https://github.com/andersensam/tensorflow-io && \
    pip install --upgrade pip && pip install uv && pip cache purge && \
    uv pip install tensorflow==2.19.1 setuptools && \
    uv pip uninstall tensorflow && \
    uv pip install --no-deps --no-index https://storage.googleapis.com/axlearn-wheels/tensorflow/tensorflow-2.19.1.3-cp312-cp312-manylinux_2_35_x86_64.whl && \
    uv cache clean

WORKDIR /workspace/tensorflow-io

# Enable busting the cache and forcing just a new bazel build
ARG BAZEL_BUILD_NUMBER 0

# Copy the TensorFlow I/O config
COPY tfio_0.37.3_ubuntu22.04.brc .bazelrc
RUN bazel build --copt="-fPIC"  --verbose_failures --spawn_strategy=local \
    --copt=-I/usr/include/tirpc --linkopt=-fuse-ld=gold \
    --per_file_copt=third_party/.*,external/.*@-Wno-error \
    -- "//tensorflow_io:python/ops/libtensorflow_io.so" "//tensorflow_io:python/ops/libtensorflow_io_plugins.so" \
    "//tensorflow_io_gcs_filesystem/..."

# Create fresh directories for the wheels and ensure we don't shadow when we build
# tensorflow-io-gcs-filesystem. Also ensure we name the wheel appropriately.
RUN rm -rf build && \
    mkdir build && \
    cp -r -L bazel-bin/tensorflow_io build/tensorflow_io && \
    python3 setup.py --data build bdist_wheel --plat-name manylinux_2_35_x86_64 && \
    rm -rf build && \
    mkdir build && \
    cp -r -L bazel-bin/tensorflow_io_gcs_filesystem  build/tensorflow_io_gcs_filesystem && \
    python3 setup.py --data build bdist_wheel --project tensorflow-io-gcs-filesystem --plat-name manylinux_2_35_x86_64 && \
    mkdir -p /mnt/export && cp dist/*.whl /mnt/export

FROM scratch AS tensorflow-io
COPY --from=tensorflow-io-build /workspace/tensorflow-io/dist /wheels