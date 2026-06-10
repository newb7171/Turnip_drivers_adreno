#!/bin/bash -e
set -euo pipefail

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

#========================
# UTIL: RETRY DOWNLOAD
#========================
download() {
	local url="$1"
	local out="$2"
	local tries=3

	for i in $(seq 1 $tries); do
		echo "Downloading ($i/$tries): $url"

		if wget -O "$out" "$url"; then
			return 0
		fi

		echo "Retrying..."
		sleep 2
	done

	echo "Failed to download: $url"
	exit 1
}

#========================
# MAIN
#========================
run_all() {
	echo "====== Mesa Turnip Build Starting ======"

	check_deps
	prepare_workdir

	cd "$workdir/$srcfolder"

	resolve_mesa_version

	build_lib_for_android
}

#========================
# DEP CHECK
#========================
check_deps() {
	deps_missing=0

	for dep in $deps; do
		if command -v "$dep" >/dev/null 2>&1; then
			echo "✓ $dep"
		else
			echo "✗ missing: $dep"
			deps_missing=1
		fi
	done

	if [ "$deps_missing" -eq 1 ]; then
		echo "Install missing dependencies first."
		exit 1
	fi

	pip3 install --quiet mako || true
}

#========================
# WORKSPACE
#========================
prepare_workdir() {
	mkdir -p "$workdir"
	cd "$workdir"

	# ---- NDK ----
	download \
		"https://github.com/SnowNF/ndk-aarch64-linux/releases/download/0.0.2/android-ndk-r29-linux-aarch64.tar.gz" \
		"ndk.tar.gz"

	echo "Extracting NDK..."
	tar -xzvf ndk.tar.gz

	# ---- Mesa ----
	rm -rf "$srcfolder"

	git clone \
		"$mesasrc" \
		--depth=1 \
		"$srcfolder"
}

#========================
# VERSION RESOLUTION
#========================
resolve_mesa_version() {
	echo "Resolving Mesa version..."

	git fetch --tags --quiet || true

	MESA_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || true)

	if [ -z "${MESA_VERSION}" ]; then
		MESA_VERSION=$(git rev-parse --short HEAD)
	fi

	# sanitize (keep numbers only where possible)
	MESA_VERSION=$(echo "$MESA_VERSION" | sed 's/[^0-9.]*//g')

	if [ -z "$MESA_VERSION" ]; then
		MESA_VERSION="unknown"
	fi

	export MESA_VERSION

	echo "Mesa version: $MESA_VERSION"
}

#========================
# BUILD
#========================
build_lib_for_android() {

	cd "$workdir/$srcfolder"

	echo "#define TUGEN8_DRV_VERSION \"v$MESA_VERSION\"" \
		> ./src/freedreno/vulkan/tu_version.h

	# ---- dynamic NDK detection ----
	NDK_DIR=$(find "$workdir" -maxdepth 1 -type d -name "android-ndk-*" | head -n 1)
	export NDK="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin"

	rm -rf build-android-aarch64

	cat <<EOF > android-aarch64.txt
[binaries]
ar = '$NDK/llvm-ar'

c = '/root/r29/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android34-clang'

cpp = ['/root/r29/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android34-clang++',
  '-fno-exceptions',
  '-fno-unwind-tables',
  '-fno-asynchronous-unwind-tables',
  '--start-no-unused-arguments',
  '-static-libstdc++',
  '--end-no-unused-arguments']
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
		--prefix /tmp/turnip \
		-Dbuildtype=release \
		-Dstrip=true \
		-Dplatforms=android \
		-Dplatform-sdk-version=$sdkver \
		-Dandroid-stub=true \
		-Dgallium-drivers= \
		-Dvulkan-drivers=freedreno \
		-Dvulkan-beta=true \
		-Dfreedreno-kmds=kgsl \
		-Degl=disabled \
		-Dandroid-libbacktrace=disabled

	ninja -C build-android-aarch64 install

	if [ ! -f /tmp/turnip/lib/libvulkan_freedreno.so ]; then
		echo "Build failed"
		exit 1
	fi

	cd /tmp/turnip/lib

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

	zip -9 "Turnip-v$MESA_VERSION.zip" \
		libvulkan_freedreno.so \
		meta.json

	echo "================================="
	echo "DONE"
	echo "Version: $MESA_VERSION"
	echo "Output: /tmp/turnip/lib/Turnip-v$MESA_VERSION.zip"
	echo "================================="
}

run_all
