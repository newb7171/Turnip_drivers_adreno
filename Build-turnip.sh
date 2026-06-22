#!/bin/bash

set -euo pipefail

workdir="$(pwd)/turnip_workdir"
ndk="$workdir/r29/toolchains/llvm/prebuilt/linux-x86_64/bin"
sysroot="$workdir/r29/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
mesasrc="https://gitlab.freedesktop.org/mesa/mesa.git"
BUILD_VERSION="26.2.0-V5.0"
PATCH_1="https://raw.githubusercontent.com/newb7171/Turnip_drivers_adreno/main/Gpu-Hacks.patch"
PATCH_2="https://raw.githubusercontent.com/newb7171/Turnip_drivers_adreno/main/KGSL-hacks-whitebelyash.diff"
PATCH_3="https://github.com/lfdevs/mesa-for-android-container/commit/0a60c9c4108200fda20016b594dcf8806f29a28e.diff"

echo "Only works in debian Arm64!!! press Ctrl + C to exit"
echo "Installing build dependencies..."

sed -i '/^Types:/ s/deb$/deb deb-src/' /etc/apt/sources.list.d/debian.sources

apt-get update
apt-get build-dep mesa -y -qq > /dev/null 2>&1
apt-get build-dep libarchive -y -qq > /dev/null 2>&1

apt-get install -y pkg-config git cmake wget zip patchelf libclc-21-dev -qq > /dev/null 2>&1

echo "setting up workdir"

mkdir -p "$workdir"
cd "$workdir"

mkdir -p "$workdir/turnip"

rm -rf "$workdir/r29"
rm -rf "$workdir/mesa"
rm -f "$workdir/android-ndk-r29-linux-aarch64.tar.gz"

echo "installing NDK and Cloning Mesa's latest source"

wget -q -nv https://github.com/SnowNF/ndk-aarch64-linux/releases/download/0.0.2/android-ndk-r29-linux-aarch64.tar.gz
tar -xzf android-ndk-r29-linux-aarch64.tar.gz

git clone $mesasrc --depth=1
cd mesa

echo "applying patches..."

wget https://raw.githubusercontent.com/whitebelyash/mesa-unified/main/src/freedreno/common/freedreno_devices.py

rm -f src/freedreno/common/freedreno_devices.py

mv freedreno_devices.py src/freedreno/common

wget "$PATCH_1"
wget "$PATCH_2"
wget "$PATCH_3"

git apply Gpu-Hacks.patch
patch -p1 -i 0a60c9c4108200fda20016b594dcf8806f29a28e.diff
patch -p1 -i KGSL-hacks-whitebelyash.diff
git add -A

echo "#define TUGEN8_DRV_VERSION \"$BUILD_VERSION\"" > ./src/freedreno/vulkan/tu_version.h

export PATH="$workdir/bin:$ndk:$PATH"
export CC=clang
export CXX=clang++
export AR=llvm-ar
export RANLIB=llvm-ranlib
export STRIP=llvm-strip
export OBJDUMP=llvm-objdump
export OBJCOPY=llvm-objcopy
export LDFLAGS="-fuse-ld=lld"

echo "setting crossfiles and setting up mesa..."

cat <<EOF > android-aarch64.txt
[binaries]
ar = '$ndk/llvm-ar'
c = ['$ndk/aarch64-linux-android35-clang', '--sysroot=$sysroot', '-fno-exceptions', '-fno-unwind-tables', '-fno-asynchronous-unwind-tables', '--start-no-unused-arguments', '-static-libstdc++', '--end-no-unused-arguments', '-Wno-error']
cpp = ['$ndk/aarch64-linux-android35-clang++', '--sysroot=$sysroot', '-fno-exceptions', '-fno-unwind-tables', '-fno-asynchronous-unwind-tables', '--start-no-unused-arguments', '-static-libstdc++', '--end-no-unused-arguments', '-Wno-error']
c_ld = '$ndk/ld.lld'
cpp_ld = '$ndk/ld.lld'
strip = '$ndk/llvm-strip'
pkg-config = ['env', 'PKG_CONFIG_LIBDIR=$sysroot/usr/lib/pkg-config', 'PKG_CONFIG_SYSROOT_DIR=$sysroot', '/usr/bin/pkg-config']

[built-in options]
c_args = ['--sysroot=$sysroot', '-Wno-error']
cpp_args = ['--sysroot=$sysroot']
c_link_args = ['--sysroot=$sysroot']
cpp_link_args = ['--sysroot=$sysroot']

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8'
endian = 'little'
EOF

cat <<EOF > native.txt
[binaries]
c = '/usr/bin/clang'
cpp = '/usr/bin/clang++'
ar = '/usr/bin/llvm-ar'
strip = '/usr/bin/llvm-strip'
c_ld = 'ld.lld'
cpp_ld = 'ld.lld'
pkg-config = '/usr/bin/pkg-config'

[build_machine]
system = 'linux'
cpu_family = 'aarch64'
cpu = 'armv8'
endian = 'little'
EOF

rm -rf build-android-aarch64

meson setup build-android-aarch64 \
    --cross-file android-aarch64.txt \
    --native-file native.txt \
    --prefix "$workdir/turnip" \
    -Dbuildtype=debugoptimized \
    -Dstrip=true \
    -Dplatforms=android \
    -Dvideo-codecs=all \
    -Dplatform-sdk-version=35 \
    -Dandroid-stub=true \
    -Dgallium-drivers= \
    -Dvulkan-drivers=freedreno \
    -Dvulkan-beta=true \
    -Dfreedreno-kmds=kgsl \
    -Degl=disabled \
    -Dandroid-strict=false \
    -Dshader-cache=true

echo "compiling mesa..."

ninja -C build-android-aarch64 install

cd "$workdir/turnip/lib"

echo "packaging turnip"

patchelf --set-soname vulkan.adreno.so libvulkan_freedreno.so
mv libvulkan_freedreno.so vulkan.adreno.so

cat <<EOF > meta.json
{
  "schemaVersion": 1,
  "name": "Mesa Turnip v$BUILD_VERSION",
  "description": "Built from source",
  "author": "JustCallMeJade",
  "packageVersion": "1",
  "vendor": "Mesa3D",
  "driverVersion": "Vulkan 1.4.335",
  "minApi": 28,
  "libraryName": "vulkan.adreno.so"
}
EOF

zip -9 "$workdir/turnip/Turnip-v$BUILD_VERSION.zip" vulkan.adreno.so meta.json

echo "BUILD_VERSION=$BUILD_VERSION" >> $GITHUB_ENV

echo "build complete."
exit 0
