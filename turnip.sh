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
deps="git meson ninja patchelf unzip curl pip3 flex bison zip glslang glslangValidator"
workdir="$(pwd)/turnip_workdir"
base_workdir="$(pwd)"

ndkver="r29"
sdkver="34"

mesasrc="https://gitlab.freedesktop.org/mesa/mesa.git"
srcfolder="mesa"
author="JustCallMeJade"

clear

#========================
# MAIN
#========================
run_all(){
	echo "====== Turnip build starting ======"
	echo "Working dir: $base_workdir"

	check_deps
	prepare_workdir

	cd "$workdir/$srcfolder"

	BUILD_VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/[^0-9.]*//g' || echo "unknown")
	export BUILD_VERSION

	build_lib_for_android turnip/gen8 gen8
	build_lib_for_android turnip/gen8 gen8-sync apply
}

#========================
# CHECK DEPS
#========================
check_deps(){
	echo "Checking dependencies..."

	deps_missing=0

	for d in $deps; do
		if command -v "$d" >/dev/null 2>&1; then
			echo -e "$green OK $d$nocolor"
		else
			echo -e "$red MISSING $d$nocolor"
			deps_missing=1
		fi
	done

	if [ "$deps_missing" -eq 1 ]; then
		echo "Install missing dependencies first"
		exit 1
	fi

	pip3 install mako >/dev/null 2>&1 || true
}

#========================
# WORKDIR
#========================
prepare_workdir(){
	echo "Preparing workspace..."

	mkdir -p "$workdir"
	cd "$workdir"

	echo "Downloading NDK..."
	wget -c https://github.com/SnowNF/ndk-aarch64-linux/releases/download/0.0.2/android-ndk-r29-linux-aarch64.tar.gz

	echo "Extracting NDK..."
	tar -xzvf android-ndk-r29-linux-aarch64.tar.gz

	echo "Cloning Mesa..."
	rm -rf "$srcfolder"
	git clone "$mesasrc" --depth=1 --no-single-branch "$srcfolder"
}

#========================
# PATCH
#========================
apply_patch(){
	echo "Applying patch $1"
	git apply "$1" || {
		echo "Patch failed: $1"
		exit 1
	}
}

#========================
# BUILD
#========================
build_lib_for_android(){
	echo "==== Building branch $1 ===="

	cd "$workdir/$srcfolder"

	git checkout --force "origin/$1"

	if [[ "${3:-}" == "apply" ]]; then
		echo "Applying patches..."
		for p in "$base_workdir"/patches/*; do
			apply_patch "$p"
		done
	fi

	echo "#define TUGEN8_DRV_VERSION \"v$BUILD_VERSION\"" \
	> ./src/freedreno/vulkan/tu_version.h

	export NDK="$workdir/$ndkver/toolchains/llvm/prebuilt/linux-x86_64/bin"

	rm -rf build-android-aarch64

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

	meson setup build-android-aarch64 \
		--cross-file android-aarch64.txt \
		--native-file native.txt \
		--prefix /tmp/turnip-$2 \
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

	ninja -C build-android-aarch64 install

	if [ ! -f /tmp/turnip-$2/lib/libvulkan_freedreno.so ]; then
		echo -e "$red BUILD FAILED$nocolor"
		exit 1
	fi

	cd /tmp/turnip-$2/lib

	cat <<EOF > meta.json
{
  "schemaVersion": 1,
  "name": "A8XX Turnip v$BUILD_VERSION",
  "description": "Built from source",
  "author": "$author",
  "packageVersion": "1",
  "vendor": "Mesa",
  "driverVersion": "Vulkan 1.4.335",
  "minApi": 28,
  "libraryName": "libvulkan_freedreno.so"
}
EOF

	zip /tmp/a8xx-$2-v$BUILD_VERSION.zip libvulkan_freedreno.so meta.json

	echo "OUTPUT: /tmp/a8xx-$2-v$BUILD_VERSION.zip"
}

run_all
