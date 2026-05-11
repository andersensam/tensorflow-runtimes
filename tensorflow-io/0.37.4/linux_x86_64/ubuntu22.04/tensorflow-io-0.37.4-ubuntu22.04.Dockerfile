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

# Fetch the correct branch, grab TensorFlow, install our custom version
# then create the tirpc symlink needed for compilation
RUN git clone --depth 1 --branch tensorflow_r2.21.0.1 https://github.com/andersensam/tensorflow-io && \
    pip install --upgrade pip uv && pip cache purge && \
    uv pip install tensorflow==2.21.0 setuptools wheel && \
    uv pip uninstall tensorflow && \
    uv pip install --no-deps --no-index https://storage.googleapis.com/axlearn-wheels/tensorflow/tensorflow-2.21.0.1-cp312-cp312-manylinux_2_35_x86_64.whl  && \
    uv cache clean && \
    ln -s /usr/include/tirpc /workspace/tensorflow-io/third_party/tirpc

WORKDIR /workspace/tensorflow-io

# Enable busting the cache and focuing just a new bazel build
ARG BAZEL_BUILD_NUMBER 0

COPY tfio_0.37.4_ubuntu22.04.brc .bazelrc
# Run the build with all flags we found necessary
RUN bazel build --noenable_bzlmod --copt="-fPIC" --verbose_failures --spawn_strategy=local \
    --copt=-Ithird_party/tirpc --linkopt=-fuse-ld=gold \
    --per_file_copt=third_party/.*,external/.*@-Wno-error \
    --per_file_copt=third_party/.*,external/.*@-Wno-implicit-function-declaration \
    --per_file_copt=third_party/.*,external/.*@-Wno-int-conversion \
    --per_file_copt=third_party/.*,external/.*@-Wno-enum-constexpr-conversion \
    --per_file_copt=third_party/.*,external/.*@-Wno-private-header \
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