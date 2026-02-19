#!/usr/bin/env python3
# coding=utf-8

import argparse
import os
import shutil
import subprocess
import sys

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def _run(command):
    print("RUN:", " ".join(command))
    result = subprocess.run(command, cwd=ROOT_DIR)
    if result.returncode != 0:
        sys.exit(result.returncode)


def _preset_by_level(level):
    if level == "release":
        return "ws63-release", "ws63-build-release"
    if level == "debug":
        return "ws63-debug", "ws63-build-debug"
    return "ws63-base", "ws63-build-debug"


def _clean_preset_dir(configure_preset):
    build_dir = os.path.join(ROOT_DIR, ".build", "cmake", configure_preset)
    if os.path.exists(build_dir):
        shutil.rmtree(build_dir)


def _build_target(target, level, clean=False, configure_only=False, extra_defines=""):
    configure_preset, build_preset = _preset_by_level(level)

    if clean:
        _clean_preset_dir(configure_preset)

    configure_cmd = [
        "cmake",
        "--preset",
        configure_preset,
        f"-DFBB_TARGET={target}",
        f"-DFBB_BUILD_LEVEL={level}",
    ]
    if extra_defines:
        configure_cmd.append(f"-DFBB_EXTRA_DEFINES={extra_defines}")
    _run(configure_cmd)

    if configure_only:
        return

    build_cmd = ["cmake", "--build", "--preset", build_preset]
    _run(build_cmd)


def _build_pack_ws63_sdk(level):
    # pack_ws63_sdk in old flow maps to sdk-package in CMake-first flow.
    _build_target("ws63-liteos-app", level, clean=False, configure_only=False)
    _run(["cmake", "--build", "--preset", "ws63-build-debug", "--target", "sdk-package"])


def main():
    parser = argparse.ArgumentParser(description="CMake-first build entry")
    parser.add_argument("target", help="Target name, e.g. ws63-liteos-app or pack_ws63_sdk")
    parser.add_argument("-c", action="store_true", dest="clean", help="clean configure dir before build")
    parser.add_argument("-release", action="store_true", dest="release")
    parser.add_argument("-debug", action="store_true", dest="debug")
    parser.add_argument("-nhso", action="store_true", dest="nhso")
    parser.add_argument("-build_time", default="", dest="build_time")
    parser.add_argument("--configure-only", action="store_true", dest="configure_only")
    parser.add_argument("--extra-defines", default="", help="semicolon separated defines")
    args = parser.parse_args()

    level = "normal"
    if args.release:
        level = "release"
    elif args.debug:
        level = "debug"

    if args.target == "pack_ws63_sdk":
        _build_pack_ws63_sdk(level)
        return

    _build_target(
        target=args.target,
        level=level,
        clean=args.clean,
        configure_only=args.configure_only,
        extra_defines=args.extra_defines,
    )


if __name__ == "__main__":
    main()
