#!/usr/bin/env python3

import os
import sys
import shutil
import subprocess
import textwrap
from pathlib import Path


# ── Configuration ────────────────────────────────────────────────────────────

WORKDIR      = Path.cwd() / "turnip_workdir"
NDK          = WORKDIR / "r29/toolchains/llvm/prebuilt/linux-x86_64/bin"
SYSROOT      = WORKDIR / "r29/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
MESA_SRC     = "https://gitlab.freedesktop.org/mesa/mesa.git"
BUILD_VERSION = "26.2.0-V5.0"

PATCHES = [
    "https://raw.githubusercontent.com/newb7171/Turnip_drivers_adreno/main/Gpu-Hacks.patch",
    "https://raw.githubusercontent.com/newb7171/Turnip_drivers_adreno/main/KGSL-hacks-whitebelyash.diff",
    "https://github.com/lfdevs/mesa-for-android-container/commit/0a60c9c4108200fda20016b594dcf8806f29a28e.diff",
    "https://github.com/lfdevs/mesa-for-android-container/commit/4bae24252a344c47a2afcd0fbd238d83bbc29f46.diff",
]


# ── Helpers ───────────────────────────────────────────────────────────────────

def run(cmd, *, cwd=None, env=None, check=True, capture=False):
    """Run a shell command, raising on failure (mirrors set -e)."""
    print(f"  $ {' '.join(str(c) for c in cmd)}")
    return subprocess.run(
        [str(c) for c in cmd],
        cwd=str(cwd) if cwd else None,
        env=env,
        check=check,
        capture_output=capture,
        text=True,
    )


def write_file(path: Path, content: str):
    path.write_text(textwrap.dedent(content))
    print(f"  wrote {path}")


# ── Steps ─────────────────────────────────────────────────────────────────────

def install_dependencies():
    print("\nInstalling build dependencies...")

    # Enable deb-src in Debian sources
    sources = Path("/etc/apt/sources.list.d/debian.sources")
    if sources.exists():
        text = sources.read_text()
        text = text.replace("Types: deb\n", "Types: deb deb-src\n")
        sources.write_text(text)

    run(["apt-get", "update"])
    run(["apt-get", "build-dep", "mesa",       "-y", "-qq"])
    run(["apt-get", "build-dep", "libarchive", "-y", "-qq"])
    run([
        "apt-get", "install", "-y",
        "pkg-config", "git", "cmake", "wget", "zip",
        "patchelf", "libclc-21-dev", "-qq",
    ])


def setup_workdir():
    print("\nSetting up workdir...")
    WORKDIR.mkdir(parents=True, exist_ok=True)
    (WORKDIR / "turnip").mkdir(parents=True, exist_ok=True)

    # Clean stale artifacts
    for target in [WORKDIR / "r29", WORKDIR / "mesa"]:
        if target.exists():
            shutil.rmtree(target)

    ndk_tar = WORKDIR / "android-ndk-r29-linux-aarch64.tar.gz"
    if ndk_tar.exists():
        ndk_tar.unlink()


def download_ndk_and_mesa():
    print("\nInstalling NDK and cloning Mesa's latest source...")

    ndk_url = (
        "https://github.com/SnowNF/ndk-aarch64-linux/releases/download/0.0.2/"
        "android-ndk-r29-linux-aarch64.tar.gz"
    )
    run(["wget", "-q", "-nv", ndk_url], cwd=WORKDIR)
    run(["tar", "-xzf", "android-ndk-r29-linux-aarch64.tar.gz"], cwd=WORKDIR)
    run(["git", "clone", MESA_SRC, "--depth=1"], cwd=WORKDIR)


def apply_patches():
    mesa_dir = WORKDIR / "mesa"
    print("\nApplying patches...")

    for url in PATCHES:
        run(["wget", url], cwd=mesa_dir)

    # git apply for .patch files; patch -p1 for .diff files
    run(["git", "apply", "Gpu-Hacks.patch"], cwd=mesa_dir)
    run(["patch", "-p1", "-i", "0a60c9c4108200fda20016b594dcf8806f29a28e.diff"], cwd=mesa_dir)
    run(["patch", "-p1", "-i", "KGSL-hacks-whitebelyash.diff"], cwd=mesa_dir)
    run(["patch", "-p1", "-i", "4bae24252a344c47a2afcd0fbd238d83bbc29f46.diff"], cwd=mesa_dir)

    run(["git", "add", "-A"], cwd=mesa_dir)

    # Write version header
    version_header = mesa_dir / "src/freedreno/vulkan/tu_version.h"
    version_header.write_text(f'#define TUGEN8_DRV_VERSION "{BUILD_VERSION}"\n')


def build_env() -> dict:
    """Return the environment dict for the build, mirroring the export block."""
    env = os.environ.copy()
    env["PATH"]     = f"{WORKDIR / 'bin'}:{NDK}:{env.get('PATH', '')}"
    env["CC"]       = "clang"
    env["CXX"]      = "clang++"
    env["AR"]       = "llvm-ar"
    env["RANLIB"]   = "llvm-ranlib"
    env["STRIP"]    = "llvm-strip"
    env["OBJDUMP"]  = "llvm-objdump"
    env["OBJCOPY"]  = "llvm-objcopy"
    env["LDFLAGS"]  = "-fuse-ld=lld"
    return env


def write_cross_files():
    mesa_dir = WORKDIR / "mesa"
    print("\nSetting cross-files...")

    cross = f"""\
        [binaries]
        ar = '{NDK}/llvm-ar'
        c = ['{NDK}/aarch64-linux-android35-clang', '--sysroot={SYSROOT}', '-fno-exceptions', '-fno-unwind-tables', '-fno-asynchronous-unwind-tables', '--start-no-unused-arguments', '-static-libstdc++', '--end-no-unused-arguments', '-Wno-error']
        cpp = ['{NDK}/aarch64-linux-android35-clang++', '--sysroot={SYSROOT}', '-fno-exceptions', '-fno-unwind-tables', '-fno-asynchronous-unwind-tables', '--start-no-unused-arguments', '-static-libstdc++', '--end-no-unused-arguments', '-Wno-error']
        c_ld = '{NDK}/ld.lld'
        cpp_ld = '{NDK}/ld.lld'
        strip = '{NDK}/llvm-strip'
        pkg-config = ['env', 'PKG_CONFIG_LIBDIR={SYSROOT}/usr/lib/pkg-config', 'PKG_CONFIG_SYSROOT_DIR={SYSROOT}', '/usr/bin/pkg-config']

        [built-in options]
        c_args = ['--sysroot={SYSROOT}', '-Wno-error']
        cpp_args = ['--sysroot={SYSROOT}']
        c_link_args = ['--sysroot={SYSROOT}']
        cpp_link_args = ['--sysroot={SYSROOT}']

        [host_machine]
        system = 'android'
        cpu_family = 'aarch64'
        cpu = 'armv8'
        endian = 'little'
    """

    native = """\
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
    """

    write_file(mesa_dir / "android-aarch64.txt", cross)
    write_file(mesa_dir / "native.txt", native)


def meson_setup():
    mesa_dir = WORKDIR / "mesa"
    build_dir = mesa_dir / "build-android-aarch64"

    if build_dir.exists():
        shutil.rmtree(build_dir)

    print("\nRunning meson setup...")
    run([
        "meson", "setup", "build-android-aarch64",
        "--cross-file", "android-aarch64.txt",
        "--native-file", "native.txt",
        "--prefix", str(WORKDIR / "turnip"),
        "-Dbuildtype=debugoptimized",
        "-Dstrip=true",
        "-Dplatforms=android",
        "-Dvideo-codecs=all",
        "-Dplatform-sdk-version=35",
        "-Dandroid-stub=true",
        "-Dgallium-drivers=",
        "-Dvulkan-drivers=freedreno",
        "-Dvulkan-beta=true",
        "-Dfreedreno-kmds=kgsl",
        "-Degl=disabled",
        "-Dandroid-strict=false",
        "-Dshader-cache=true",
    ], cwd=mesa_dir, env=build_env())


def compile_and_install():
    mesa_dir = WORKDIR / "mesa"
    print("\nCompiling Mesa...")
    run(["ninja", "-C", "build-android-aarch64", "install"],
        cwd=mesa_dir, env=build_env())


def package_turnip():
    lib_dir = WORKDIR / "turnip" / "lib"
    print("\nPackaging Turnip...")

    run(["patchelf", "--set-soname", "vulkan.adreno.so", "libvulkan_freedreno.so"],
        cwd=lib_dir)
    (lib_dir / "libvulkan_freedreno.so").rename(lib_dir / "vulkan.adreno.so")

    meta = f"""\
        {{
          "schemaVersion": 1,
          "name": "Mesa Turnip v{BUILD_VERSION}",
          "description": "Built from source",
          "author": "JustCallMeJade",
          "packageVersion": "1",
          "vendor": "Mesa3D",
          "driverVersion": "Vulkan 1.4.335",
          "minApi": 28,
          "libraryName": "vulkan.adreno.so"
        }}
    """
    write_file(lib_dir / "meta.json", meta)

    zip_path = WORKDIR / "turnip" / f"Turnip-v{BUILD_VERSION}.zip"
    run(["zip", "-9", str(zip_path), "vulkan.adreno.so", "meta.json"],
        cwd=lib_dir)


def github_actions_export():
    if os.environ.get("GITHUB_ACTIONS") == "true":
        github_env = os.environ.get("GITHUB_ENV", "")
        if github_env:
            with open(github_env, "a") as f:
                f.write(f"BUILD_VERSION={BUILD_VERSION}\n")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print("Only works on Debian ARM64!!! Press Ctrl+C to exit.")

    install_dependencies()
    setup_workdir()
    download_ndk_and_mesa()
    apply_patches()
    write_cross_files()
    meson_setup()
    compile_and_install()
    package_turnip()
    github_actions_export()

    print("\nBuild complete.")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as e:
        print(f"\nError: command failed with exit code {e.returncode}", file=sys.stderr)
        sys.exit(e.returncode)
    except KeyboardInterrupt:
        print("\nAborted by user.")
        sys.exit(1)
