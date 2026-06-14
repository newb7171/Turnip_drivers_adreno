#!/bin/bash -e
set -euo pipefail

NDK="/root/r29/toolchains/llvm/prebuilt/linux-x86_64/bin"
MESA="26.2.0-V3"
MESA_SOURCE="https://gitlab.freedesktop.org/mesa/mesa.git"
NDK_DOWNLOAD="https://github.com/SnowNF/ndk-aarch64-linux/releases/download/0.0.2/android-ndk-r29-linux-aarch64.tar.gz"
PATCH_1="https://raw.githubusercontent.com/newb7171/Turnip_drivers_adreno/main/patch.patch"
OUTPUT_DIR="/root/turnip"
NDK_NAME="android-ndk-r29-linux-aarch64.tar.gz"

sed -i '/^Types:/ s/deb/deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources

apt-get update

apt-get build-dep mesa -y

apt build-dep libarchive -y

apt-get install -y 
pkg-config 
git 
cmake 
wget 
zip 
patchelf 
libarchive-dev 
expat 
libxml2-dev

rm -rf /root/r29
rm -rf /root/mesa
rm -f /root/android-ndk-r29-linux-aarch64.tar.gz
rm -rf /root/turnip

wget "$NDK_DOWNLOAD"

tar -xzvf "$NDK_NAME"

git clone "$MESA_SOURCE" --depth=1

cd mesa

wget "$PATCH_1"

git apply patch.patch

git add -A

git commit -m "Added patch"

echo "#define TUGEN8_DRV_VERSION "$MESA"" > src/freedreno/vulkan/tu_version.h

rm -rf build-android-aarch64

cat <<EOF > android-aarch64.txt
[binaries]
ar = '$NDK/llvm-ar'
c = '$NDK/aarch64-linux-android35-clang'
cpp = ['$NDK/aarch64-linux-android35-clang++', '-fno-exceptions', '-fno-unwind-tables', '-fno-asynchronous-unwind-tables', '--start-no-unused-arguments', '-static-libstdc++', '--end-no-unused-arguments']
c_ld = '$NDK/ld.lld'
cpp_ld = '$NDK/ld.lld'
strip = '$NDK/llvm-strip'
pkg-config = 'pkg-config'

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8'
endian = 'little'
EOF

cat <<EOF > native.txt
[build_machine]
c = 'clang'
cpp = 'clang++'
ar = 'llvm-ar'
strip = 'llvm-strip'
c_ld = 'ld.lld'
cpp_ld = 'ld.lld'
system = 'linux'
cpu_family = 'aarch64'
cpu = 'armv8'
endian = 'little'
EOF

rm -rf "$OUTPUT_DIR"

meson setup build-android-aarch64 
--cross-file android-aarch64.txt 
--native-file native.txt 
--prefix "$OUTPUT_DIR" 
-Dbuildtype=release 
-Dstrip=true 
-Dplatforms=android 
-Dplatform-sdk-version=35 
-Dandroid-stub=true 
-Dgallium-drivers= 
-Dvulkan-drivers=freedreno 
-Dvulkan-beta=true 
-Dfreedreno-kmds=kgsl 
-Degl=disabled 
-Dandroid-libbacktrace=disabled

ninja -C build-android-aarch64 -j4 install

cd "$OUTPUT_DIR/lib"

patchelf --set-soname vulkan.adreno.so libvulkan_freedreno.so

mv libvulkan_freedreno.so vulkan.adreno.so

cat <<EOF > meta.json
{
"schemaVersion": 1,
"name": "Mesa Turnip v$MESA",
"description": "Built from source",
"author": "JustCallMeJade",
"packageVersion": "1",
"vendor": "Mesa3d",
"driverVersion": "Vulkan 1.4.335",
"minApi": 28,
"libraryName": "vulkan.adreno.so"
}
EOF

zip -9 "$OUTPUT_DIR/Turnip-v$MESA.zip" 
vulkan.adreno.so 
meta.json

echo "Build complete."

exit 0
