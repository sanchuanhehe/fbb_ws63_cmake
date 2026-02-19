#!/usr/bin/env python3
# coding=utf-8

import argparse
import json
import os


def load_target_env(path):
    with open(path, "r", encoding="utf-8") as file:
        return json.load(file)


def build_contract(env_data, cmake_binary_dir):
    chip = env_data.get("CHIP", "")
    core = env_data.get("CORE", "")
    target = env_data.get("TARGET", "")
    bin_name = env_data.get("BIN_NAME", target)
    output_root = env_data.get("OUTPUT_ROOT", "")

    target_output_dir = os.path.join(output_root, chip, core, target)

    return {
        "schema": "fbb.build.contract/v1",
        "target": target,
        "chip": chip,
        "core": core,
        "output_root": output_root,
        "stages": {
            "configure": {
                "inputs": [
                    "build/script/export_target_env.py",
                    "build/config/target_config"
                ],
                "outputs": [
                    os.path.join(cmake_binary_dir, "fbb_generated", target, "target_env.json"),
                    os.path.join(cmake_binary_dir, "fbb_generated", target, "target_env.cmake")
                ]
            },
            "compile": {
                "inputs": [
                    "CMakeLists.txt",
                    "build/cmake"
                ],
                "outputs": [
                    os.path.join(cmake_binary_dir, f"{bin_name}.elf"),
                    os.path.join(cmake_binary_dir, f"{bin_name}.bin"),
                    os.path.join(cmake_binary_dir, f"{bin_name}.map")
                ]
            },
            "postbuild": {
                "inputs": [
                    "build/cmake/build_sign.cmake",
                    "build/cmake/build_nv_bin.cmake",
                    "build/cmake/build_hso_database.cmake"
                ],
                "outputs": [
                    target_output_dir,
                    os.path.join(output_root, chip, "package")
                ]
            },
            "package": {
                "inputs": [
                    "tools/pkg/packet.py",
                    f"build/config/target_config/{chip}/build_{chip}_update.py"
                ],
                "outputs": [
                    os.path.join(output_root, chip, "fwpkg")
                ]
            },
            "sdk": {
                "inputs": [
                    "build/script/sdk_generator/sdk_generator.py"
                ],
                "outputs": [
                    os.path.join(output_root, "sdk")
                ]
            }
        }
    }


def main():
    parser = argparse.ArgumentParser(description="Export build contract for CMake consumption")
    parser.add_argument("--target-env-json", required=True, help="Path to exported target env json")
    parser.add_argument("--cmake-binary-dir", required=True, help="CMake binary dir")
    parser.add_argument("--out", required=True, help="Contract output file")
    args = parser.parse_args()

    env_data = load_target_env(args.target_env_json)
    contract = build_contract(env_data, os.path.abspath(args.cmake_binary_dir))

    out_dir = os.path.dirname(os.path.abspath(args.out))
    os.makedirs(out_dir, exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as file:
        json.dump(contract, file, indent=2, ensure_ascii=False)

    print(f"Build contract generated: {args.out}")


if __name__ == "__main__":
    main()
