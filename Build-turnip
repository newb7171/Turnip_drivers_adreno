#!/bin/bash

set -euo pipefail

workdir="$(pwd)/turnip_workdir"
ndk="$workdir/r29/toolchains/llvm/prebuilt/linux-x86_64/bin"
mesasrc="https://gitlab.freedesktop.org/mesa/mesa.git"
BUILD_VERSION="26.2.0-V4"
PATCH_1="https://raw.githubusercontent.com/newb7171/Turnip_drivers_adreno/main/patch.patch"

echo "Only works in debian!!! press Ctrl + C to exit"
echo "Installing build dependencies..."

sed -i '/^Types:/ s/deb$/deb deb-src/' /etc/apt/sources.list.d/debian.sources

apt-get update
apt-get build-dep mesa -y -qq
apt-get build-dep libarchive -y -qq

apt-get install -y pkg-config git cmake wget zip patchelf libclc-21-dev -qq

mkdir -p "$workdir"
cd "$workdir"

mkdir -p "$workdir/turnip"

rm -rf "$workdir/r29"
rm -rf "$workdir/mesa"
rm -f "$workdir/android-ndk-r29-linux-aarch64.tar.gz"

wget https://github.com/SnowNF/ndk-aarch64-linux/releases/download/0.0.2/android-ndk-r29-linux-aarch64.tar.gz
tar -xzf android-ndk-r29-linux-aarch64.tar.gz

git clone $mesasrc --depth=1
cd mesa

echo "Applying patch..."
wget "$PATCH_1"
git apply patch.patch

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

cat <<EOF > android-aarch64.txt
[binaries]
ar = '$ndk/llvm-ar'
c = ['$ndk/aarch64-linux-android35-clang', '-fno-exceptions', '-fno-unwind-tables', '-fno-asynchronous-unwind-tables', '--start-no-unused-arguments', '-static-libstdc++', '--end-no-unused-arguments', '-Wno-error']
cpp = ['$ndk/aarch64-linux-android35-clang++', '-fno-exceptions', '-fno-unwind-tables', '-fno-asynchronous-unwind-tables', '--start-no-unused-arguments', '-static-libstdc++', '--end-no-unused-arguments', '-Wno-error']
c_ld = '$ndk/ld.lld'
cpp_ld = '$ndk/ld.lld'
strip = '$ndk/llvm-strip'
pkg-config = ['env', 'PKG_CONFIG_LIBDIR=$ndk/pkg-config', '/usr/bin/pkg-config']

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
    -Degl=disabled

ninja -C build-android-aarch64 install

cd "$workdir/turnip/lib"

patchelf --set-soname vulkan.adreno.so libvulkan_freedreno.so
mv libvulkan_freedreno.so vulkan.adreno.so

cat <<EOF > meta.json
{
  "schemaVersion": 1,
  "name": "Mesa Turnip v$BUILD_VERSION",
  "description": "Built from source",
  "author": "JustCallMeJade",
  "packageVersion": "1",
  "vendor": "Mesa3d",
  "driverVersion": "Vulkan 1.4.335",
  "minApi": 28,
  "libraryName": "vulkan.adreno.so"
}
EOF

zip -9 "$workdir/turnip/Turnip-v$BUILD_VERSION.zip" vulkan.adreno.so meta.json

# ignore this. this is for github actions

echo "BUILD_VERSION=$BUILD_VERSION" >> $GITHUB_ENV

echo "build complete."
exit 0
