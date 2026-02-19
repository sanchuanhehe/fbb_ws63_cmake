#!/usr/bin/env python3
# encoding=utf-8
# ============================================================================
# @brief    Build nvbin
# Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2023-2023. All rights reserved.
# ============================================================================

import os
import sys
import json
import glob
import argparse
file_dir = os.path.dirname(os.path.realpath(__file__))
g_root = os.path.realpath(os.path.join(file_dir, "..", "..", "..", ".."))
sys.path.append(os.path.join(g_root, 'build', 'script', 'nv'))
from nv_binary import nv_begin


def _parse_args():
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("target_name", nargs="?", default="")
    parser.add_argument("--target-name", dest="target_name_opt", default="")
    parser.add_argument("--chip", default="")
    parser.add_argument("--core", default="")
    parser.add_argument("--output-root", default="")
    parser.add_argument("--input-manifest", default="")
    parser.add_argument("--output-manifest", default="")
    args, _ = parser.parse_known_args()
    return args


def _load_manifest_inputs(manifest_path):
    if not manifest_path or not os.path.isfile(manifest_path):
        return []
    inputs = [os.path.abspath(manifest_path)]
    try:
        with open(manifest_path, "r", encoding="utf-8") as mf:
            data = json.load(mf)
    except (OSError, ValueError, TypeError):
        return inputs
    outputs = data.get("outputs", [])
    if isinstance(outputs, list):
        for item in outputs:
            if isinstance(item, str) and os.path.exists(item):
                inputs.append(os.path.abspath(item))
    produced_bins = data.get("produced_bins", [])
    if isinstance(produced_bins, list):
        for item in produced_bins:
            if isinstance(item, str) and os.path.exists(item):
                inputs.append(os.path.abspath(item))
    return sorted(set(inputs))


if __name__ == '__main__':
    args = _parse_args()
    target_name = args.target_name_opt or args.target_name
    chip = args.chip or (os.environ.get("FBB_CHIP", "ws63").strip() or "ws63")
    core = args.core or (os.environ.get("FBB_CORE", "acore").strip() or "acore")
    fbb_output_root = args.output_root or os.environ.get("FBB_OUTPUT_ROOT", "").strip()
    input_manifest = args.input_manifest or os.environ.get("FBB_NV_INPUT_MANIFEST", "").strip()

    #配置文件路径
    nv_config_json = os.path.join(g_root, "build", "config", "target_config", "ws63", "nv_bin_cfg", "mk_nv_bin_cfg.json")
    targets = ["acore"]
    if target_name:
        if target_name == 'ws63-liteos-perf':
            nv_config_json = os.path.join(g_root, "build", "config", "target_config", "ws63", "nv_bin_cfg",
                                          "mk_nv_bin_cfg_perf.json")

    runtime_nv_cfg = nv_config_json
    if fbb_output_root:
        with open(nv_config_json, "r", encoding="utf-8") as cfg_file:
            cfg = json.load(cfg_file)
        out_bin_dir = os.path.join(fbb_output_root, chip, core, "nv_bin")
        build_temp_path = os.path.join(fbb_output_root, chip)
        nv_relative_path = os.path.join(out_bin_dir, "temp")
        cfg["OUT_BIN_DIR"] = out_bin_dir
        cfg["BUILD_TEMP_PATH"] = build_temp_path
        cfg["NV_RELATIVE_PATH"] = nv_relative_path
        cfg["DATABASE_TXT_FILE"] = nv_relative_path
        runtime_nv_cfg = os.path.join(fbb_output_root, "nv_config", "mk_nv_bin_cfg.runtime.json")
        os.makedirs(os.path.dirname(runtime_nv_cfg), exist_ok=True)
        with open(runtime_nv_cfg, "w", encoding="utf-8") as runtime_file:
            json.dump(cfg, runtime_file, ensure_ascii=False, indent=4)

    with open(runtime_nv_cfg, "r", encoding="utf-8") as cfg_file:
        cfg = json.load(cfg_file)
    nv_output_path = os.path.join(g_root, cfg["OUT_BIN_DIR"])
    if not os.path.exists(nv_output_path):
        os.makedirs(nv_output_path)

    nv_begin(runtime_nv_cfg, targets, 1, True)

    manifest_path = args.output_manifest or os.environ.get("FBB_NV_MANIFEST", "").strip()
    if manifest_path:
        os.makedirs(os.path.dirname(os.path.abspath(manifest_path)), exist_ok=True)
        produced_bins = sorted(glob.glob(os.path.join(nv_output_path, "*.bin")))
        input_files = [os.path.abspath(runtime_nv_cfg)]
        input_files.extend(_load_manifest_inputs(input_manifest))
        manifest = {
            "schema_version": "fbb.stage-manifest.v1",
            "stage": "ws63.nv",
            "target": target_name,
            "chip": chip,
            "core": core,
            "inputs": sorted(set(input_files)),
            "command": sys.argv,
            "outputs": produced_bins,
            "produced_files": produced_bins,
            "success": True,
            "exit_code": 0,
            "runtime_config": os.path.abspath(runtime_nv_cfg),
            "output_dir": os.path.abspath(nv_output_path),
            "produced_bins": produced_bins
        }
        with open(manifest_path, "w", encoding="utf-8") as manifest_file:
            json.dump(manifest, manifest_file, ensure_ascii=False, indent=2)
