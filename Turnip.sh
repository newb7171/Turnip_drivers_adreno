#!/bin/bash -e

set -uo pipefail

########################################
# CI CONFIG
########################################
WORKDIR="/root/Turnip"
MESADIR="$WORKDIR/mesa"
OUTDIR="/root/turnip/lib"

########################################
# SAFETY CHECK
########################################
echo "[CI] Turnip Freedreno CI starting..."

echo "This must run as root with deb-src enabled."
echo "Press A to continue, B to exit."

read -r input
case "$input" in
    A|a) echo "[CI] Starting build..." ;;
    B|b) exit 0 ;;
    *) echo "Invalid"; exit 1 ;;
esac

########################################
# PHASE 1 - SYSTEM DEPENDENCIES
########################################
echo "[1/6] Updating system..."
apt update && apt upgrade -y

echo "[1/6] Installing dependencies..."
apt build-dep mesa -y

apt install -y \
    git wget cmake pkg-config patchelf zip \
    meson ninja-build ccache clang lld \
    expat libarchive-dev libxml2 libxml2-dev

########################################
# PHASE 2 - SOURCE
########################################
echo "[2/6] Preparing workspace..."
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "[2/6] Cloning Mesa..."
git clone https://gitlab.freedesktop.org/mesa/mesa.git --depth 1

########################################
# PHASE 3 - NDK
########################################
echo "[3/6] Installing NDK..."
wget -q https://github.com/SnowNF/ndk-aarch64-linux/releases/download/0.0.2/android-ndk-r29-linux-aarch64.tar.gz

tar -xf android-ndk-r29-linux-aarch64.tar.gz

export NDK="/root/r29/toolchains/llvm/prebuilt/linux-x86_64/bin"

########################################
# PHASE 4 - BUILD CONFIG
########################################
echo "[4/6] Configuring build..."
cd mesa

cat <<EOF > android-aarch64.txt
[binaries]
ar = '$NDK/llvm-ar'
c = ['ccache', '$NDK/aarch64-linux-android34-clang']
cpp = ['ccache', '$NDK/aarch64-linux-android34-clang++']
c_ld = '$NDK/ld.lld'
cpp_ld = '$NDK/ld.lld'
strip = '$NDK/llvm-strip'

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8'
endian = 'little'
EOF

cat <<EOF > native.txt
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

meson setup build \
    --cross-file android-aarch64.txt \
    --native-file native.txt \
    --prefix /root/turnip \
    -Dbuildtype=release \
    -Dvulkan-drivers=freedreno \
    -Dplatforms=android \
    -Dgallium-drivers= \
    -Degl=disabled \
    -Dandroid-stub=true \
    -Dplatform-sdk-version=34

########################################
# PHASE 5 - BUILD
########################################
echo "[5/6] Building..."
ninja -C build -j"$(nproc)"

echo "[5/6] Installing..."
ninja -C build install

########################################
# PHASE 6 - PACKAGE
########################################
echo "[6/6] Packaging..."

cd "$OUTDIR"

patchelf --set-soname vulkan.ad07xx.so libvulkan_freedreno.so
mv libvulkan_freedreno.so vulkan.ad07xx.so

cd "$MESADIR"

RAW_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "unknown")
VERSION=$(echo "$RAW_TAG" | sed 's/[^0-9.]*//g')

NAME="A8XX Turnip v$VERSION"
ZIP="Turnip-v$VERSION.zip"

cd "$OUTDIR"

cat <<EOF > meta.json
{
  "schemaVersion": 1,
  "name": "$NAME",
  "description": "Freedreno Turnip Vulkan driver built from source",
  "author": "JustCallMeJade",
  "vendor": "Mesa",
  "driverVersion": "Vulkan 1.4.335",
  "libraryName": "vulkan.ad07xx.so"
}
EOF

zip -r "$ZIP" vulkan.ad07xx.so meta.json

echo "[CI] DONE"
echo "Artifact: $OUTDIR/$ZIP"
