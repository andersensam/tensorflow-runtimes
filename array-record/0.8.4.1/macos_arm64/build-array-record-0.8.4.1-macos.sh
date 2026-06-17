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

cd "$ORIGINAL_DIR/build/array_record"
BAZEL_VERSION=7.6.1 PYTHON_VERSION=$PYTHON_VERSION PYTHON_MINOR_VERSION=$PYTHON_MINOR_VERSION \
  PYTHON_BIN=$PYTHON_BIN ./oss/build_whl.sh

mkdir -p -v "$ORIGINAL_DIR/wheels"
cp -v /tmp/array_record/all_dist/*.whl "$ORIGINAL_DIR/wheels/"

echo "All done!"
