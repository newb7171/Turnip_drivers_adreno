#!/bin/bash

workdir="$(pwd)/turnip_workdir"
ndk="$workdir/r29/toolchains/llvm/prebuilt/linux-x86_64/bin" #yes r29 is the directory
sysroot="$workdir/r29/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
mesasrc="https://gitlab.freedesktop.org/mesa/mesa.git"
BUILD_VERSION="26.2.0-V6.1" #this script is always maintained just update when new version.
VERSION="V6.1"
PATCH_1="https://raw.githubusercontent.com/newb7171/Turnip_drivers_adreno/main/Gpu-Hacks.patch"
PATCH_2="https://raw.githubusercontent.com/newb7171/Turnip_drivers_adreno/main/KGSL-hacks-whitebelyash.diff"
PATCH_3="https://github.com/lfdevs/mesa-for-android-container/commit/0a60c9c4108200fda20016b594dcf8806f29a28e.diff"
PATCH_5="https://github.com/lfdevs/mesa-for-android-container/commit/216d25275a57bc543944eb369a4e31ce3733a9a1.diff"
PATCH_4="https://github.com/lfdevs/mesa-for-android-container/commit/4bae24252a344c47a2afcd0fbd238d83bbc29f46.diff"
PATCH_6="https://github.com/lfdevs/mesa-for-android-container/commit/b23ef04b8e95e04ae4c77bb8c0bdcdcc97f813d7.diff"
PATCH_7="https://raw.githubusercontent.com/JustCallMeJade/Turnip_drivers_adreno/main/40159.diff"
PATCH_8="https://gitlab.freedesktop.org/mesa/mesa/-/merge_requests/42498.patch"

echo "Only works in debian Arm64!!! press Ctrl + C to exit"
echo "Installing build dependencies..."

sed -i '/^Types:/ s/$/ deb-src/' /etc/apt/sources.list.d/debian.sources
    
apt-get update
apt-get build-dep mesa -y -qq > /dev/null 2>&1
apt-get build-dep libarchive -y -qq > /dev/null 2>&1

apt-get install -y pkg-config git cmake wget zip patchelf libclc-21-dev -qq > /dev/null 2>&1

mkdir -p "$workdir"
cd "$workdir"

mkdir -p "$workdir/turnip"

rm -rf "$workdir/r29"
rm -rf "$workdir/mesa"
rm -f "$workdir/android-ndk-r29-linux-aarch64.tar.gz"

wget -q -nv https://github.com/SnowNF/ndk-aarch64-linux/releases/download/0.0.2/android-ndk-r29-linux-aarch64.tar.gz
tar -xzf android-ndk-r29-linux-aarch64.tar.gz

git clone $mesasrc --depth=1
cd mesa

rm -f VERSION

cat <<EOF > VERSION
26.2.0-$VERSION
EOF

for patch in \
"$PATCH_1" \
"$PATCH_2" \
"$PATCH_3" \
"$PATCH_4" \
"$PATCH_5" \
"$PATCH_6" \
"$PATCH_7" \
"$PATCH_8"
do
    wget "$patch"
done

wget https://gitlab.freedesktop.org/mesa/mesa/-/merge_requests/42489.diff
wget https://gitlab.freedesktop.org/mesa/mesa/-/merge_requests/35924.diff

git apply Gpu-Hacks.patch
patch -p1 -i 0a60c9c4108200fda20016b594dcf8806f29a28e.diff
patch -p1 -i KGSL-hacks-whitebelyash.diff
patch -p1 -i 4bae24252a344c47a2afcd0fbd238d83bbc29f46.diff
patch -p1 -i 216d25275a57bc543944eb369a4e31ce3733a9a1.diff
patch -p1 -i b23ef04b8e95e04ae4c77bb8c0bdcdcc97f813d7.diff
patch -p1 -i 40159.diff
patch -p1 -i 42498.patch
git add -A

echo "#define TUGEN8_DRV_VERSION \"$BUILD_VERSION\"" > ./src/freedreno/vulkan/tu_version.h

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
c = 'clang'
cpp = 'clang++'
ar = 'llvm-ar'
strip = 'llvm-strip'
c_ld = 'ld.lld'
cpp_ld = 'ld.lld'
pkg-config = 'pkg-config'

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

echo "packaging turnip"

patchelf --set-soname vulkan.adreno.so libvulkan_freedreno.so
mv libvulkan_freedreno.so vulkan.adreno.so

cat <<EOF > meta.json
{
  "schemaVersion": 1,
  "name": "Mesa Turnip v$BUILD_VERSION",
  "description": "Built from Mesa source + GPU hacks",
  "author": "JustCallMeJade",
  "packageVersion": "1",
  "vendor": "Mesa3D",
  "driverVersion": "Vulkan 1.4.354",
  "minApi": 28,
  "libraryName": "vulkan.adreno.so"
}
EOF

zip -9 "$workdir/turnip/Turnip-v$BUILD_VERSION.zip" vulkan.adreno.so meta.json

if [ "$GITHUB_ACTIONS" = "true" ]; then
    echo "BUILD_VERSION=$BUILD_VERSION" >> "$GITHUB_ENV"
fi

echo "build complete."
exit 0
