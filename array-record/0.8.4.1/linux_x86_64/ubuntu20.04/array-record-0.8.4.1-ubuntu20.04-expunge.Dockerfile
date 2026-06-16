# syntax=docker/dockerfile:1

ARG TARGET=array-record
ARG BASE_IMAGE=cuda-12.9-toolchain:ubuntu20.04

FROM ${BASE_IMAGE} AS build

WORKDIR /workspace

# Clone the repository
RUN git clone --depth 1 --branch 0.8.4.1 https://github.com/andersensam/array_record.git /workspace/array_record
WORKDIR /workspace/array_record

# Purge the Bazel cache
RUN --mount=type=cache,target=/root/.cache/bazel,id=bazel-cache-array-record-0.8.4.1-ubuntu20.04-x86_64 \
    bazel clean --expunge
