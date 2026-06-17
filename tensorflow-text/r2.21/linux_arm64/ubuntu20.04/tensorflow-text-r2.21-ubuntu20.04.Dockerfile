# syntax=docker/dockerfile:1

ARG TARGET=tensorflow-text
ARG BASE_IMAGE=cuda-12.8-toolchain:ubuntu20.04-arm64
    
# Use the CUDA 12.8 runtime image (for TensorFlow) (cuda-12.8-toolchain-ubuntu20.04.Dockerfile)
# to greatly speed up build time.
FROM ${BASE_IMAGE} AS tensorflow-text-build

RUN mkdir -p /workspace/text
WORKDIR /workspace/text

# Enable busting the cache and forcing a git refresh and new bazel build
ARG GIT_BUILD_NUMBER 0

# Initialize the TensorFlow repo
RUN git init /workspace/text && git config --global --add safe.directory /workspace/text && \
    git remote add origin https://github.com/andersensam/text && \
    git -c protocol.version=2 fetch --no-tags --prune --no-recurse-submodules --depth=1 origin && \
    git checkout 2.21

# Enable busting the cache and forcing just a new bazel build
ARG BAZEL_BUILD_NUMBER 0

# Set the env since we aren't using the normal build targets
ENV PYTHON_BIN_PATH="/opt/venv/python3.12/bin/python3.12" \
    PYTHON_LIB_PATH="/opt/venv/lib/python3.12/site-packages" \
    HERMETIC_PYTHON_VERSION=3.12 \
    HERMETIC_CUDA_VERSION="12.8.1" \
    HERMETIC_CUDNN_VERSION="9.8.0" \
    HERMETIC_CUDA_COMPUTE_CAPABILITIES="compute_90,compute_100,compute_101,compute_120,sm_90a,sm_100a,sm_101a,sm_120a" \
    HERMETIC_NCCL_VERSION="2.27.7" \
    CLANG_CUDA_COMPILER_PATH="/opt/llvm/bin/clang" \
    CPP_PATH="/opt/llvm/bin/clang++" \
    CXX="/opt/llvm/bin/clang++" \
    GCC_PATH="/opt/llvm/bin/clang" \
    CC="/opt/llvm/bin/clang" \
    CLANG_COMPILER_PATH="/opt/llvm/bin/clang"

# Copy the configs into the image
COPY text_r2.21_ubuntu20.04_arm64.brc .bazelrc
COPY text_r2.21_ubuntu20.04_arm64.tfc .tf_configure.bazelrc
# Use the TensorFlow cache, if it exists since it pulls many of the same deps
RUN --mount=type=cache,target=/root/.cache/bazel,id=bazel-cache-r2.21.0.1-ubuntu20.04-arm64 \
    bazel run --experimental_repo_remote_exec --repo_env=USE_PYWRAP_RULES=False \
      //oss_scripts/pip_package:build_pip_package -- /workspace/text/dist

# Export the wheels
RUN --mount=type=cache,target=/root/.cache/bazel,id=bazel-cache-r2.21.0.1-ubuntu20.04-arm64 \
    cp /workspace/text/dist/*.whl /workspace && \
    mkdir -p /mnt/export && cp -rf /workspace/*.whl /mnt/export

FROM scratch AS tensorflow-text
COPY --from=tensorflow-text-build /mnt/export /wheels