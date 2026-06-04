#!/bin/bash -e

set -uo pipefail

fail() {
    echo
    echo "ERROR: $1"
    exit 1
}

trap 'fail "script only works in root or apt operation failed"' ERR

echo "WARNING: This script only works when run as root."
echo "You must also have deb-src entries enabled in your APT sources."
echo
echo "Press B to exit."
echo "Press A to continue."

read -r choice

case "$choice" in
    A|a)
        echo "Continuing..."
        ;;
    B|b)
        echo "Exiting."
        exit 0
        ;;
    *)
        echo "Invalid option."
        exit 1
        ;;
esac

echo "[1/14] Updating package lists and upgrading system..."
apt update && apt upgrade -y || fail "script only works in root"

echo "[2/14] Installing Mesa build dependencies..."
apt build-dep mesa -y || fail "you should put deb-src in your apt lists"

echo "[3/14] Installing required tools and libraries..."
apt install -y \
    cmake \
    pkg-config \
    git \
    wget \
    patchelf \
    meson \
    ninja-build \
    ccache \
    clang \
    lld \
    expat \
    libarchive-dev \
    libxml2 \
    libxml2-dev || fail "script only works in root"

echo "[4/14] Creating Turnip workspace..."
mkdir -p Turnip
cd Turnip

echo "[5/14] Downloading Android NDK..."
wget https://github.com/SnowNF/ndk-aarch64-linux/releases/download/0.0.2/android-ndk-r29-linux-aarch64.tar.gz

echo "[6/14] Extracting Android NDK..."
tar -xzvf android-ndk-r29-linux-aarch64.tar.gz

echo "[7/14] Setting NDK environment..."
export NDK=/root/r29/toolchains/llvm/prebuilt/linux-x86_64/bin

echo "[8/14] Cloning Mesa..."
git clone https://gitlab.freedesktop.org/mesa/mesa.git --depth 1

cd mesa

echo "[9/14] Writing Android cross-file..."
cat <<'EOF' > android-aarch64.txt
[binaries]
ar = '$NDK/llvm-ar'
c = ['ccache', '$NDK/aarch64-linux-android34-clang']
cpp = ['ccache', '$NDK/aarch64-linux-android34-clang++', '-fno-exceptions', '-fno-unwind-tables', '-fno-asynchronous-unwind-tables', '--start-no-unused-arguments', '-static-libstdc++', '--end-no-unused-arguments']
c_ld = '$NDK/ld.lld'
cpp_ld = '$NDK/ld.lld'
strip = '$NDK/llvm-strip'
pkg-config = ['env', 'PKG_CONFIG_LIBDIR=$NDK/pkg-config', '/usr/bin/pkg-config']

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8'
endian = 'little'

[properties]
sysroot = '/root/r29/toolchains/llvm/prebuilt/linux-x86_64/sysroot'
EOF

echo "[10/14] Writing native build file..."
cat <<'EOF' > native.txt
[build_machine]
c = ['ccache', 'clang']
cpp = ['ccache', 'clang++']
ar = 'llvm-ar'
strip = 'llvm-strip'
c_ld = 'ld.lld'
cpp_ld = 'ld.lld'
system = 'linux'
cpu_family = 'aarch64'
cpu = 'armv8'
endian = 'little'
EOF

echo "[11/14] Configuring Mesa build..."
meson setup build-android-aarch64 \
    --cross-file android-aarch64.txt \
    --native-file native.txt \
    --prefix /root/turnip \
    -Dbuildtype=release \
    -Dstrip=true \
    -Dplatforms=android \
    -Dvideo-codecs= \
    -Dplatform-sdk-version=34 \
    -Dandroid-stub=true \
    -Dgallium-drivers= \
    -Dvulkan-drivers=freedreno \
    -Degl=disabled \
    -Dandroid-libbacktrace=disabled \
    -Dvulkan-beta=true

echo "[12/14] Building Mesa..."
ninja -C build-android-aarch64 -j"$(nproc)"

echo "[13/14] Installing Turnip..."
ninja -C build-android-aarch64 install

echo "[14/14] Finalizing output..."
cd ..
cd turnip/lib

patchelf --set-soname vulkan.ad07xx.so libvulkan_freedreno.so
mv libvulkan_freedreno.so vulkan.ad07xx.so

echo
echo "Build complete!"
