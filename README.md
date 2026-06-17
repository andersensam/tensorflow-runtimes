# tensorflow-runtimes

Containerized runtimes for building TensorFlow and related packages.

## How to use this repo

Each of the directories in the root of this repo represent a package to build, related to TensorFlow. Within the directories are target versions to build, platform to build on, and base image.

The reason for providing various base images is for `GLIBC` and `GLIBCXX` versioning.

In the Dockerfiles contained within this repo, there may be some shared build steps, found in the `common` directory. These (as of June 2026) include Python 3.12 and LLVM 22.1.7.

## Building TensorFlow

Building TensorFlow requires a sequence of steps to be completed, starting out with creating the common runtime images.

### Building TensorFlow 2.21.0.3 on an Ubuntu 20.04 (GLIBC 2.31) base:

```shell
# Build Python 3.12
cd common/linux_x86_64/ubuntu20.04/python-3.12
docker build . -f python-3.12-ubuntu20.04.Dockerfile -t python-3.12-ubuntu20.04
# Build LLVM 22.1.7
cd ../llvm-22.1.7
docker build . -f llvm-22.1.7-ubuntu20.04.Dockerfile -t llvm-22.1.7-ubuntu20.04
# Build the CUDA 12.9 toolchain
cd ../cuda-12.9-toolchain
docker build . -f cuda-12.9-toolchain-ubuntu20.04.Dockerfile -t cuda-12.9-toolchain-ubuntu20.04
# Build TensorFlow 
cd ../../../tensorflow/r2.21/linux_x86_64/ubuntu20.04
docker build . -f tensorflow-r2.21.0.3-ubuntu20.04.Dockerfile -t tensorflow-r2.21.0.3-ubuntu20.04 --build-arg GIT_BUILD_NUMBER=202606171005
```

Note that we use `--build-arg GIT_BUILD_NUMBER` to force a new git checkout.

There are also "expunge" dockerfiles provided throughout the repo to force bazel to clear the cache. They can be used by:

```shell
cd tensorflow/r2.21/linux_x86_64/ubuntu20.04
docker build . -f tensorflow-r2.21.0.3-ubuntu20.04-expunge.Dockerfile -t exp --build-arg GIT_BUILD_NUMBER=202606171005 --no-cache
```

### Building TensorFlow 2.21.0.3 on an Ubuntu 22.04 (GLIBC 2.35) base:

```shell
# Build Python 3.12
cd common/linux_x86_64/ubuntu22.04/python-3.12
docker build . -f python-3.12-ubuntu22.04.Dockerfile -t python-3.12-ubuntu22.04
# Build the CUDA 12.9 toolchain
cd ../cuda-12.9-toolchain
docker build . -f cuda-12.9-toolchain-ubuntu22.04.Dockerfile -t cuda-12.9-toolchain-ubuntu22.04
# Build TensorFlow 
cd ../../../tensorflow/r2.21/linux_x86_64/ubuntu22.04
docker build . -f tensorflow-r2.21.0.3-ubuntu22.04.Dockerfile -t tensorflow-r2.21.0.3-ubuntu22.04 --build-arg GIT_BUILD_NUMBER=202606171005
```

Note that for Ubuntu 22.04, we do not need to build LLVM from source, as the LLVM distribution natively works with GLIBC 2.35. Unless you have an explicit need for older GLIBC, using Ubuntu 22.04 is recommended for building TensorFlow.


### Building TensorFlow 2.21.0.3 on macOS:

To build TensorFlow on macOS, we need to use a different approach, as we are not using Docker. Please ensure that your target Python version is already installed. As of June 2026, only Python 3.12 has been tested for compilation.

```shell
# Build TensorFlow
cd tensorflow/r2.21/macos_arm64
bash build-tensorflow-r2.21.0.3-macos.sh
```

The script will download bazel and then build TensorFlow, dumping the wheel into the TensorFlow build directory.

### Building TensorFlow 2.19.0.4

The same process can be used for building TensorFlow 2.19.0.4, just changing out directories for the appropriate version.
