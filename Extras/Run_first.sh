#!/bin/bash -e

sed -i '/^Types:/ {/deb-src/! s/$/ deb-src/;}' /etc/apt/sources.list.d/ubuntu.sources

apt-get update && apt upgrade -y && \
apt-get build-dep mesa -y && \
apt-get install -y cmake pkg-config patchelf wget
