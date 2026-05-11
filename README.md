# tensorflow-runtimes

Containerized runtimes for building TensorFlow and related packages.

## How to use this repo

Each of the directories in the root of this repo represent a package to build, related to TensorFlow. Within the directories are target versions to build, platform to build on, and base image.

The reason for providing various base images is for `GLIBC` and `GLIBCXX` versioning.

In the Dockerfiles contained within this repo, there may be some shared build steps, found in the `common` directory. These (as of May 2026) include Python 3.12 and LLVM 20.