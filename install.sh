#!/bin/bash -e

sed -i '/^Types:/ s/deb/deb deb-src/' /etc/apt/sources.list.d/debian.sources

apt update && apt upgrade -y && apt build-dep mesa -y && apt install wget patchelf zip -y
