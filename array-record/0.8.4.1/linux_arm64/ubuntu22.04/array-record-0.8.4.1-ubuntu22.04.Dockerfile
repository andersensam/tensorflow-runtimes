# syntax=docker/dockerfile:1

ARG TARGET=array-record
ARG BASE_IMAGE=cuda-12.9-toolchain:ubuntu22.04-arm64

FROM ${BASE_IMAGE} AS build

WORKDIR /workspace

# Enable busting the cache and forcing a git refresh and new bazel build
ARG GIT_BUILD_NUMBER 0

# Set environment variables to compile with LLVM-22
ENV CC=/opt/llvm/bin/clang CXX=/opt/llvm/bin/clang++

# Clone the repository
RUN git clone --depth 1 --branch 0.8.4.1 https://github.com/andersensam/array_record.git /workspace/array_record
WORKDIR /workspace/array_record

# Enable busting the cache and focusing just a new bazel build
ARG BAZEL_BUILD_NUMBER 0

# Build the C++ and Python extensions with Bazel
RUN --mount=type=cache,target=/root/.cache/bazel,id=bazel-cache-array-record-0.8.4.1-ubuntu22.04-arm64 \
    bazel build ... \
        -c opt \
        --@rules_python//python/config_settings:python_version=3.12 \
        --copt=-fvisibility=default \
        --cxxopt=-fvisibility=default \
        --cxxopt=-std=c++17 \
        --host_cxxopt=-std=c++17 \
        --cxxopt=-Wno-deprecated-declarations \
        --cxxopt=-Wno-parentheses \
        --cxxopt=-Wno-sign-compare \
        --linkopt=-Wl,--allow-shlib-undefined \
        --host_linkopt=-Wl,--allow-shlib-undefined

# Run Bazel tests to ensure correctness
RUN --mount=type=cache,target=/root/.cache/bazel,id=bazel-cache-array-record-0.8.4.1-ubuntu22.04-arm64 \
    bazel test ... \
        -c opt \
        --@rules_python//python/config_settings:python_version=3.12 \
        --copt=-fvisibility=default \
        --cxxopt=-fvisibility=default \
        --cxxopt=-std=c++17 \
        --host_cxxopt=-std=c++17 \
        --cxxopt=-Wno-deprecated-declarations \
        --cxxopt=-Wno-parentheses \
        --cxxopt=-Wno-sign-compare \
        --linkopt=-Wl,--allow-shlib-undefined \
        --host_linkopt=-Wl,--allow-shlib-undefined \
        --verbose_failures \
        --test_output=errors


# Reorganize files for setup.py
RUN --mount=type=cache,target=/root/.cache/bazel,id=bazel-cache-array-record-0.8.4.1-ubuntu22.04-arm64 \
    python3 <<EOF
import os
import shutil

os.makedirs('/workspace/build/array_record', exist_ok=True)
shutil.copy('setup.py', '/workspace/build/')
shutil.copy('LICENSE', '/workspace/build/')

def copy_tree(src, dst):
    for root, dirs, files in os.walk(src):
        dirs[:] = [d for d in dirs if not d.startswith('bazel-')]
        rel_path = os.path.relpath(root, src)
        target_dir = dst if rel_path == '.' else os.path.join(dst, rel_path)
        os.makedirs(target_dir, exist_ok=True)
        for f in files:
            shutil.copy2(os.path.join(root, f), os.path.join(target_dir, f))

copy_tree('.', '/workspace/build/array_record')

def copy_built_files(src_dir, dst_dir):
    for root, dirs, files in os.walk(src_dir):
        dirs[:] = [d for d in dirs if d != '.runfiles' and not d.endswith('_obj')]
        for f in files:
            if f.endswith('.so') or f.endswith('_pb2.py'):
                rel_path = os.path.relpath(root, src_dir)
                target_dir = os.path.join(dst_dir, rel_path)
                os.makedirs(target_dir, exist_ok=True)
                shutil.copy2(os.path.join(root, f), os.path.join(target_dir, f))

copy_built_files('bazel-bin/cpp', '/workspace/build/array_record/cpp')
copy_built_files('bazel-bin/python', '/workspace/build/array_record/python')
EOF


# Build the wheel
WORKDIR /workspace/build
RUN uv pip install auditwheel && \
    python3 setup.py bdist_wheel --python-tag py312 && \
    auditwheel repair --plat manylinux_2_35_aarch64 -w repaired_dist dist/*.whl && \
    uv pip install -f https://storage.googleapis.com/axlearn-wheels/wheels.html tensorflow==2.21.0.3 repaired_dist/*.whl && \
    python3 -c 'import tensorflow as tf; from array_record.python import array_record_module; print("SUCCESS: array_record imported alongside tensorflow!")' && \
    mkdir -p /mnt/export && cp repaired_dist/*.whl /mnt/export/

FROM scratch AS array-record
COPY --from=build /mnt/export /wheels
