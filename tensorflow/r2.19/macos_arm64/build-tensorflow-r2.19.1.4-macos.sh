#!/bin/bash

# Setup a temporary directory for building TensorFlow
mkdir build

# Ensure Python 3.12 is already installed and is accessible
python3.12 -m venv build/.venv
source build/.venv/bin/activate
pip install --upgrade pip uv

# Fetch the bazel binary
curl -o build/bazel https://storage.googleapis.com/axlearn-wheels/bazelisk/v1.29.0/bazelisk-darwin-arm64
chmod +x build/bazel

# Clone TensorFlow
cd build && git clone --depth 1 --branch r2.19 https://github.com/andersensam/tensorflow

# Generate the .tf_configure.bazelrc for building TensorFlow
echo "build --action_env PYTHON_BIN_PATH=\"$(pwd)/.venv/bin/python3.12\"" > tensorflow/.tf_configure.bazelrc
echo "build --action_env PYTHON_LIB_PATH=\"$(pwd)/.venv/lib/python3.12/site-packages\"" >> tensorflow/.tf_configure.bazelrc
echo "build --python_path=\"$(pwd)/.venv/bin/python3.12\"" >> tensorflow/.tf_configure.bazelrc

# Copy the rest of the template .tf_configure.bazelrc
cat ../tf_r2.19.1.4_macos_arm64.brc >> tensorflow/.tf_configure.bazelrc

# Start building TensorFlow
export CC_OPT_FLAGS="-Wno-gnu-offsetof-extensions -Wno-error -Wno-c23-extensions -Wno-macro-redefined"
export HERMETIC_PYTHON_VERSION=3.12
cd tensorflow && ../bazel build //tensorflow/tools/pip_package:wheel --repo_env=WHEEL_NAME=tensorflow --config=macos_arm64 \
    --copt=-Wno-gnu-offsetof-extensions --copt=-Wno-error --copt=-Wno-c23-extensions --verbose_failures \
    --copt=-Wno-macro-redefined --define=no_system_libs=true --action_env TF_SYSTEM_LIBS=""
