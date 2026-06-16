#!/bin/bash
# MacOS compilation and packaging script for ArrayRecord.

set -e

ORIGINAL_DIR=$(pwd)
mkdir -p "$ORIGINAL_DIR/build"

if [ ! -d "$ORIGINAL_DIR/build/array_record" ]; then
  echo "Cloning array_record 0.8.4.1..."
  git clone --depth 1 --branch 0.8.4.1 https://github.com/andersensam/array_record.git "$ORIGINAL_DIR/build/array_record"
fi

# 1. Detect Python from virtual environment or path
if [ -n "$VIRTUAL_ENV" ]; then
  PYTHON_BIN="$VIRTUAL_ENV/bin/python"
  echo "Using Python from active virtual environment: $PYTHON_BIN"
else
  PYTHON_BIN=$(which python3)
  echo "WARNING: No active virtual environment detected. Using system python: $PYTHON_BIN"
fi

if [ -z "$PYTHON_BIN" ] || [ ! -f "$PYTHON_BIN" ]; then
  echo "Error: Python 3 executable not found."
  exit 1
fi

# Get python version
PYTHON_VERSION=$("$PYTHON_BIN" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PYTHON_MINOR_VERSION=$("$PYTHON_BIN" -c 'import sys; print(sys.version_info.minor)')
echo "Detected Python version: $PYTHON_VERSION"

# Ensure setuptools and wheel are installed
"$PYTHON_BIN" -m pip install -q -U setuptools wheel

# Change directory to cloned repo
cd "$ORIGINAL_DIR/build/array_record"

# Prepare dist/ directory, cleaning up old wheels to avoid conflicts during smoke tests
mkdir -p dist
rm -f dist/*.whl

# 2. Build array_record_module C++ extension with Bazel
echo "Building C++ extension using Bazel for Python $PYTHON_VERSION..."
bazel build -c opt \
  --cxxopt=-std=c++17 \
  --host_cxxopt=-std=c++17 \
  --cxxopt=-Wno-deprecated-declarations \
  --host_cxxopt=-Wno-deprecated-declarations \
  --action_env MACOSX_DEPLOYMENT_TARGET='11.0' \
  --action_env PYTHON_BIN_PATH="$PYTHON_BIN" \
  --@rules_python//python/config_settings:python_version="${PYTHON_VERSION}" \
  //python:array_record_module

# 3. Create temp directory for clean packaging
TMPDIR=$(mktemp -d -t array_record_pkg.XXXXXXXXXX)
echo "Staging files in temporary directory: $TMPDIR"

# Copy python packages and metadata
mkdir -p "$TMPDIR/array_record"
cp setup.py "$TMPDIR/"
cp LICENSE "$TMPDIR/"

# Use rsync to copy only needed packages, avoiding bazel symlinks, build artifacts, and C++ extensions
rsync -av \
  --exclude="bazel-*" \
  --exclude="dist" \
  --exclude="build" \
  --exclude="*.egg-info" \
  --exclude=".git" \
  --exclude=".bazel*" \
  --exclude="*.so" \
  --exclude="__pycache__" \
  . "$TMPDIR/array_record/"

# Copy built extension into Python package inside the staging directory
cp -f bazel-bin/python/array_record_module.so "$TMPDIR/array_record/python/array_record_module.so"
chmod +w "$TMPDIR/array_record/python/array_record_module.so"

# 4. Build Wheel
echo "Building Python wheel..."
pushd "$TMPDIR" > /dev/null
"$PYTHON_BIN" setup.py bdist_wheel --python-tag py3"${PYTHON_MINOR_VERSION}" --plat-name macosx_11_0_"$(uname -m)"
popd > /dev/null

# 5. Move wheel back to original directory
mkdir -p "$ORIGINAL_DIR/dist"
cp "$TMPDIR"/dist/*.whl "$ORIGINAL_DIR/dist/"
echo "Successfully generated wheel in $ORIGINAL_DIR/dist/:"
ls -lh "$ORIGINAL_DIR/dist/"*.whl

# Clean up temp dir
rm -rf "$TMPDIR"

# 6. Run Smoke Test
echo "Running validation test..."
# Install the wheel we just built
"$PYTHON_BIN" -m pip install --force-reinstall "$ORIGINAL_DIR/dist/"*.whl

# Run import test in /tmp to ensure we aren't loading local source files
cd /tmp
"$PYTHON_BIN" -c 'import tensorflow as tf; from array_record.python import array_record_module; print("SUCCESS: array_record imported alongside tensorflow!")'

echo "All done!"
