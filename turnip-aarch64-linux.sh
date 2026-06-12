#!/bin/bash -e
set -euo pipefail

pip3 install --quiet mako || true

mkdir -p "$(pwd)/turnip_workdir"
cd "$(pwd)/turnip_workdir"

rm -rf r29
wget -O "ndk.tar.gz" "https://github.com/SnowNF/ndk-aarch64-linux/releases/download/0.0.2/android-ndk-r29-linux-aarch64.tar.gz"
tar -xzvf ndk.tar.gz

rm -rf Mesa-android
git clone "https://gitlab.freedesktop.org/mesa/mesa.git" --depth=1 "Mesa-android"
cd "$(pwd)/turnip_workdir/Mesa-android"

cat <<'PATCH_EOF' > patch.patch
From 0000000000000000000000000000000000000000 Mon Sep 17 00:00:00 2001
From: Mesa Contributor <contributor@example.com>
Date: Fri, 12 Jun 2026 00:00:00 +0000
Subject: [PATCH] freedreno: add Adreno 710, 720, and 722 GPU entries

--- a/src/freedreno/common/freedreno_devices.py
+++ b/src/freedreno/common/freedreno_devices.py
@@ -962,6 +962,229 @@
         [A6XXRegs.REG_A6XX_UCHE_UNKNOWN_0E12, 0],
     ]
 
+a710_magic_regs = dict(
+        RB_DBG_ECO_CNTL = 0x00000000,
+        RB_DBG_ECO_CNTL_blit = 0x00000000,
+        RB_RBP_CNTL = 0x0,
+)
+
+a710_raw_magic_regs = [
+        [A6XXRegs.REG_A6XX_UCHE_CACHE_WAYS, 0x00040004],
+        [A6XXRegs.REG_A6XX_TPL1_DBG_ECO_CNTL, 0x01000000],
+        [A6XXRegs.REG_A6XX_TPL1_DBG_ECO_CNTL1, 0x00000700],
+        [A6XXRegs.REG_A6XX_SP_CHICKEN_BITS, 0x00000400],
+        [A6XXRegs.REG_A7XX_SP_CHICKEN_BITS_1, 0x00400400],
+        [A6XXRegs.REG_A7XX_SP_CHICKEN_BITS_2, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_CHICKEN_BITS_3, 0x00000000],
+        [A6XXRegs.REG_A7XX_UCHE_UNKNOWN_0E10, 0x00000000],
+        [A6XXRegs.REG_A7XX_UCHE_UNKNOWN_0E11, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_HLSQ_DBG_ECO_CNTL, 0x00000000],
+        [A6XXRegs.REG_A6XX_SP_DBG_ECO_CNTL, 0x10000000],
+        [A6XXRegs.REG_A6XX_PC_MODE_CNTL, 0x00001f1f],
+        [A6XXRegs.REG_A6XX_PC_DBG_ECO_CNTL, 0x20100000],
+        [A6XXRegs.REG_A7XX_PC_UNKNOWN_9E24, 0x01fc7f00],
+        [A6XXRegs.REG_A7XX_VFD_DBG_ECO_CNTL, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_ISDB_CNTL, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_AE6A, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_HLSQ_TIMEOUT_THRESHOLD_DP, 0x00000080],
+        [A6XXRegs.REG_A7XX_SP_HLSQ_DBG_ECO_CNTL_1, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_HLSQ_MODE_CNTL, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_AB01, 0x00000001],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_AB22, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_B310, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_0CE2,   0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_0CE2+1, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_0CE4,   0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_0CE4+1, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_0CE6,   0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_0CE6+1, 0x00000000],
+        [A6XXRegs.REG_A7XX_GRAS_ROTATION_CNTL, 0x00000000],
+        [A6XXRegs.REG_A6XX_GRAS_DBG_ECO_CNTL,  0x00000800],
+        [A6XXRegs.REG_A7XX_RB_UNKNOWN_8E79, 0x00000000],
+        [A6XXRegs.REG_A7XX_RB_LRZ_CNTL2, 0x00000000],
+        [A6XXRegs.REG_A7XX_RB_CCU_DBG_ECO_CNTL, 0x00080000],
+        [A6XXRegs.REG_A6XX_VPC_DBG_ECO_CNTL, 0x02000000],
+        [A6XXRegs.REG_A6XX_UCHE_UNKNOWN_0E12, 0x03200000],
+]
+
+a720_magic_regs = dict(
+        RB_DBG_ECO_CNTL = 0x00000000,
+        RB_DBG_ECO_CNTL_blit = 0x00000000,
+        RB_RBP_CNTL = 0x0,
+)
+
+a720_raw_magic_regs = [
+        [A6XXRegs.REG_A6XX_UCHE_CACHE_WAYS, 0x00040004],
+        [A6XXRegs.REG_A6XX_TPL1_DBG_ECO_CNTL, 0x03000000],
+        [A6XXRegs.REG_A6XX_TPL1_DBG_ECO_CNTL1, 0x00000700],
+        [A6XXRegs.REG_A6XX_SP_CHICKEN_BITS, 0x00001400],
+        [A6XXRegs.REG_A7XX_SP_CHICKEN_BITS_1, 0x01400400],
+        [A6XXRegs.REG_A7XX_SP_CHICKEN_BITS_2, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_CHICKEN_BITS_3, 0x00000000],
+        [A6XXRegs.REG_A7XX_UCHE_UNKNOWN_0E10, 0x00000000],
+        [A6XXRegs.REG_A7XX_UCHE_UNKNOWN_0E11, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_HLSQ_DBG_ECO_CNTL, 0x00000000],
+        [A6XXRegs.REG_A6XX_SP_DBG_ECO_CNTL, 0x11000000],
+        [A6XXRegs.REG_A6XX_PC_MODE_CNTL, 0x00001f1f],
+        [A6XXRegs.REG_A6XX_PC_DBG_ECO_CNTL, 0x20100000],
+        [A6XXRegs.REG_A7XX_PC_UNKNOWN_9E24, 0x01fc7f00],
+        [A6XXRegs.REG_A7XX_VFD_DBG_ECO_CNTL, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_ISDB_CNTL, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_AE6A, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_HLSQ_TIMEOUT_THRESHOLD_DP, 0x00000080],
+        [A6XXRegs.REG_A7XX_SP_HLSQ_DBG_ECO_CNTL_1, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_HLSQ_MODE_CNTL, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_AB01, 0x00000001],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_AB22, 0x00000000],
+        [A7XXRegs.REG_A7XX_SP_UNKNOWN_B310, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_0CE2,   0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_0CE2+1, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_0CE4,   0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_0CE4+1, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_0CE6,   0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_0CE6+1, 0x00000000],
+        [A6XXRegs.REG_A7XX_GRAS_ROTATION_CNTL, 0x00000000],
+        [A6XXRegs.REG_A6XX_GRAS_DBG_ECO_CNTL,  0x00000800],
+        [A7XXRegs.REG_A7XX_RB_UNKNOWN_8E79, 0x00000000],
+        [A6XXRegs.REG_A7XX_RB_LRZ_CNTL2, 0x00000000],
+        [A6XXRegs.REG_A7XX_RB_CCU_DBG_ECO_CNTL, 0x00000000],
+        [A6XXRegs.REG_A6XX_VPC_DBG_ECO_CNTL, 0x02000000],
+        [A6XXRegs.REG_A6XX_UCHE_UNKNOWN_0E12, 0x03200000],
+]
+
+a722_magic_regs = dict(
+        RB_DBG_ECO_CNTL = 0x00000000,
+        RB_DBG_ECO_CNTL_blit = 0x00000000,
+        RB_RBP_CNTL = 0x0,
+)
+
+a722_raw_magic_regs = [
+        [A6XXRegs.REG_A6XX_UCHE_CACHE_WAYS, 0x00000000],
+        [A6XXRegs.REG_A6XX_TPL1_DBG_ECO_CNTL, 0x03000000],
+        [A6XXRegs.REG_A6XX_TPL1_DBG_ECO_CNTL1, 0x00000700],
+        [A6XXRegs.REG_A6XX_SP_CHICKEN_BITS, 0x00000400],
+        [A6XXRegs.REG_A7XX_SP_CHICKEN_BITS_1, 0x01400400],
+        [A6XXRegs.REG_A7XX_SP_CHICKEN_BITS_2, 0x00000010],
+        [A6XXRegs.REG_A7XX_SP_CHICKEN_BITS_3, 0x00000000],
+        [A6XXRegs.REG_A7XX_UCHE_UNKNOWN_0E10, 0x00000000],
+        [A6XXRegs.REG_A7XX_UCHE_UNKNOWN_0E11, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_HLSQ_DBG_ECO_CNTL, 0x00000000],
+        [A6XXRegs.REG_A6XX_SP_DBG_ECO_CNTL, 0x11000000],
+        [A6XXRegs.REG_A6XX_PC_MODE_CNTL, 0x0000003f],
+        [A6XXRegs.REG_A6XX_PC_DBG_ECO_CNTL, 0x20100000],
+        [A6XXRegs.REG_A7XX_PC_UNKNOWN_9E24, 0x01fc7f00],
+        [A6XXRegs.REG_A7XX_VFD_DBG_ECO_CNTL, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_ISDB_CNTL, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_AE6A, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_HLSQ_TIMEOUT_THRESHOLD_DP, 0x00000080],
+        [A6XXRegs.REG_A7XX_SP_HLSQ_DBG_ECO_CNTL_1, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_HLSQ_MODE_CNTL, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_AB01, 0x00000001],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_AB22, 0x00000000],
+        [A7XXRegs.REG_A7XX_SP_UNKNOWN_B310, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_0CE2,   0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_0CE2+1, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_0CE4,   0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_0CE4+1, 0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_0CE6,   0x00000000],
+        [A6XXRegs.REG_A7XX_SP_UNKNOWN_0CE6+1, 0x00000000],
+        [A6XXRegs.REG_A7XX_GRAS_ROTATION_CNTL, 0x00000000],
+        [A6XXRegs.REG_A6XX_GRAS_DBG_ECO_CNTL,  0x00000800],
+        [A7XXRegs.REG_A7XX_RB_UNKNOWN_8E79, 0x00000000],
+        [A6XXRegs.REG_A7XX_RB_LRZ_CNTL2, 0x00000000],
+        [A6XXRegs.REG_A7XX_RB_CCU_DBG_ECO_CNTL, 0x00080000],
+        [A6XXRegs.REG_A6XX_VPC_DBG_ECO_CNTL, 0x02000000],
+        [A6XXRegs.REG_A6XX_UCHE_UNKNOWN_0E12, 0x03200000],
+]
+
+add_gpus([
+        GPUId(chip_id=0x07010000, name="FD710"),
+        GPUId(chip_id=0xffff07010000, name="FD710"),
+    ], A6xxGPUInfo(
+        CHIP.A7XX,
+        [a7xx_base, a7xx_gen1],
+        num_ccu = 3,
+        tile_align_w = 64,
+        tile_align_h = 32,
+        tile_max_w = 1024,
+        tile_max_h = 1024,
+        num_vsc_pipes = 32,
+        cs_shared_mem_size = 32 * 1024,
+        wave_granularity = 2,
+        fibers_per_sp = 128 * 2 * 16,
+        highest_bank_bit = 16,
+        magic_regs = a710_magic_regs,
+        raw_magic_regs = a710_raw_magic_regs,
+    ))
+
+add_gpus([
+        GPUId(chip_id=0x43020000, name="FD720"),
+        GPUId(chip_id=0xffff43020000, name="FD720"),
+    ], A6xxGPUInfo(
+        CHIP.A7XX,
+        [a7xx_base, a7xx_gen1],
+        num_ccu = 3,
+        tile_align_w = 64,
+        tile_align_h = 32,
+        tile_max_w = 1024,
+        tile_max_h = 1024,
+        num_vsc_pipes = 32,
+        cs_shared_mem_size = 32 * 1024,
+        wave_granularity = 2,
+        fibers_per_sp = 128 * 2 * 16,
+        highest_bank_bit = 16,
+        magic_regs = a720_magic_regs,
+        raw_magic_regs = a720_raw_magic_regs,
+    ))
+
+add_gpus([
+        GPUId(chip_id=0x43020100, name="FD722"),
+        GPUId(chip_id=0xffff43020100, name="FD722"),
+    ], A6xxGPUInfo(
+        CHIP.A7XX,
+        [a7xx_base, a7xx_gen1],
+        num_ccu = 3,
+        tile_align_w = 64,
+        tile_align_h = 32,
+        tile_max_w = 1024,
+        tile_max_h = 1024,
+        num_vsc_pipes = 32,
+        cs_shared_mem_size = 32 * 1024,
+        wave_granularity = 2,
+        fibers_per_sp = 128 * 2 * 16,
+        highest_bank_bit = 16,
+        magic_regs = a722_magic_regs,
+        raw_magic_regs = a722_raw_magic_regs,
+    ))
+
 add_gpus([
         GPUId(chip_id=0x07030002, name="FD725"),
PATCH_EOF

git apply patch.patch
git add -A

echo '#define TUGEN8_DRV_VERSION "v26.2.0-V2.1"' > ./src/freedreno/vulkan/tu_version.h

export NDK="$(find "$(pwd)/../" -maxdepth 1 -type d -name "android-ndk-*" | head -n 1)/toolchains/llvm/prebuilt/linux-x86_64/bin"

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

meson setup build-android-aarch64 \
	--cross-file android-aarch64.txt \
	--native-file native.txt \
	--prefix /tmp/turnip \
	-Dbuildtype=release \
	-Dstrip=true \
	-Dplatforms=android \
	-Dplatform-sdk-version=35 \
	-Dandroid-stub=true \
	-Dgallium-drivers= \
	-Dvulkan-drivers=freedreno \
	-Dvulkan-beta=true \
	-Dfreedreno-kmds=kgsl \
	-Degl=disabled \
	-Dandroid-libbacktrace=disabled

ninja -C build-android-aarch64 -j$(nproc)
ninja -C build-android-aarch64 install 
cd /tmp/turnip/lib

patchelf --set-soname vulkan.ad07xx.so libvulkan_freedreno.so
mv libvulkan_freedreno.so vulkan.ad07xx.so

cat <<EOF > meta.json
{
  "schemaVersion": 1,
  "name": "Mesa Turnip v26.2.0-V2.1",
  "description": "Built from source",
  "author": "JustCallMeJade",
  "packageVersion": "1",
  "vendor": "Mesa",
  "driverVersion": "Vulkan 1.4.335",
  "minApi": 28,
  "libraryName": "vulkan.ad07xx.so"
}
EOF

zip -9 "Turnip-v26.2.0-V2.1.zip" vulkan.ad07xx.so meta.json
