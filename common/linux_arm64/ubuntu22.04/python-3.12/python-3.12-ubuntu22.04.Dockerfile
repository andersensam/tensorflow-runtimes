# syntax=docker/dockerfile:1

ARG TARGET=python
ARG BASE_IMAGE=ubuntu:22.04

FROM --platform=linux/arm64 ${BASE_IMAGE} AS python-build
# Build Python 3.12
RUN mkdir -p /tmp/staging
WORKDIR /tmp/staging
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install build-essential zlib1g-dev libncurses5-dev libgdbm-dev \
        libnss3-dev libssl-dev libreadline-dev libffi-dev pkg-config wget \
        libbz2-dev liblzma-dev libsqlite3-dev uuid-dev libgdbm-compat-dev \
        tk-dev curl gnupg && \
    apt clean -y && \
    curl -o Python-3.12.12.tgz https://www.python.org/ftp/python/3.12.12/Python-3.12.12.tgz && \
    tar -xvf Python-3.12.12.tgz && \
    ./Python-3.12.12/configure --enable-optimizations --with-ensurepip=install --prefix=/opt/python3.12 && \
    make all -j$(nproc) && \
    make altinstall -j$(nproc) && \
    apt-get remove -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev \
        libnss3-dev libssl-dev libreadline-dev libffi-dev pkg-config wget \
        libbz2-dev liblzma-dev libsqlite3-dev uuid-dev libgdbm-compat-dev \
        tk-dev curl gnupg && \
    apt-get autoremove -y && \
    apt clean -y && \
    rm -rf ./*

FROM scratch AS python
COPY --from=python-build /opt/python3.12 /python3.12