#!/bin/bash -euo pipefail

#========================
# COLORS
#========================
green='\033[0;32m'
red='\033[0;31m'
nocolor='\033[0m'

#========================
# CONFIG
#========================
deps="git meson ninja patchelf unzip curl pip3 flex bison zip glslang glslangValidator wget"
workdir="$(pwd)/turnip_workdir"

ndkver="r29"
sdkver="34"

mesasrc="https://gitlab.freedesktop.org/mesa/mesa.git"
srcfolder="mesa"
author="JustCallMeJade"

clear

#========================
# MAIN
#========================
run_all() {
	echo "====== Mesa Turnip Build Starting ======"

	check_deps
	prepare_workdir

	cd "$workdir/$srcfolder"

	MESA_VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/[^0-9.]*//g')

	if [ -z "$MESA_VERSION" ]; then
		MESA_VERSION="unknown"
	fi

	export MESA_VERSION

	build_lib_for_android
}

#========================
# DEPENDENCIES
#========================
check_deps() {
	echo "Checking dependencies..."

	deps_missing=0

	for dep in $deps; do
		if command -v "$dep" >/dev/null 2>&1; then
			echo -e "${green}✓ $dep found${nocolor}"
		else
			echo -e "${red}✗ $dep missing${nocolor}"
			deps_missing=1
		fi
	done

	if [ "$deps_missing" -eq 1 ]; then
		echo "Please install missing dependencies."
		exit 1
	fi

	echo "Installing Python mako module..."
	pip3 install --quiet mako || true
}

#========================
# WORKSPACE
#========================
prepare_workdir() {
	echo "Preparing workspace..."

	mkdir -p "$workdir"
	cd "$workdir"

	echo "Downloading Android NDK..."

	wget https://github.com/SnowNF/ndk-aarch64-linux/releases/download/0.0.2/android-ndk-r29-linux-aarch64.tar.gz

	echo "Extracting Android NDK..."

	rm -rf "$ndkver"

	tar -xzvf android-ndk-r29-linux-aarch64.tar.gz

	echo "Cloning Mesa..."

	rm -rf "$srcfolder"

	git clone \
		"$mesasrc" \
		--depth=1 \
		--no-single-branch \
		"$srcfolder"
}

#========================
# BUILD
#========================
build_lib_for_android() {

	cd "$workdir/$srcfolder"

	echo "#define TUGEN8_DRV_VERSION \"v$MESA_VERSION\"" \
		> ./src/freedreno/vulkan/tu_version.h

	export NDK="$workdir/$ndkver/toolchains/llvm/prebuilt/linux-x86_64/bin"

	echo "Creating Meson cross files..."

	cat <<EOF > android-aarch64.txt
[binaries]
ar = '$NDK/llvm-ar'
c = '$NDK/aarch64-linux-android$sdkver-clang'
cpp = '$NDK/aarch64-linux-android$sdkver-clang++'
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

	echo "Removing old build directory..."
	rm -rf build-android-aarch64

	echo "Configuring Mesa..."

	meson setup build-android-aarch64 \
		--cross-file android-aarch64.txt \
		--native-file native.txt \
		--prefix /tmp/turnip \
		-Dbuildtype=release \
		-Dstrip=true \
		-Dplatforms=android \
		-Dvideo-codecs= \
		-Dplatform-sdk-version=$sdkver \
		-Dandroid-stub=true \
		-Dgallium-drivers= \
		-Dvulkan-drivers=freedreno \
		-Dvulkan-beta=true \
		-Dfreedreno-kmds=kgsl \
		-Degl=disabled \
		-Dandroid-libbacktrace=disabled

	echo "Building Turnip..."

	ninja -C build-android-aarch64 install

	if [ ! -f /tmp/turnip/lib/libvulkan_freedreno.so ]; then
		echo -e "${red}Build failed!${nocolor}"
		exit 1
	fi

	cd /tmp/turnip/lib

	echo "Generating metadata..."

	cat <<EOF > meta.json
{
  "schemaVersion": 1,
  "name": "Mesa Turnip v$MESA_VERSION",
  "description": "Built from source",
  "author": "$author",
  "packageVersion": "1",
  "vendor": "Mesa",
  "driverVersion": "Vulkan 1.4.335",
  "minApi": 28,
  "libraryName": "libvulkan_freedreno.so"
}
EOF

	echo "Creating archive..."

	zip -9 "Turnip-v$MESA_VERSION.zip" \
		libvulkan_freedreno.so \
		meta.json

	echo
	echo "================================="
	echo "Build completed successfully!"
	echo "Mesa Version: $MESA_VERSION"
	echo "Output:"
	echo "/tmp/turnip/lib/Turnip-v$MESA_VERSION.zip"
	echo "================================="
}

run_all
