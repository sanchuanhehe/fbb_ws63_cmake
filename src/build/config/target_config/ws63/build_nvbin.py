#!/usr/bin/env python3
# encoding=utf-8
# ============================================================================
# @brief    Build nvbin
# Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2023-2023. All rights reserved.
# ============================================================================

import os
import sys
import json
file_dir = os.path.dirname(os.path.realpath(__file__))
g_root = os.path.realpath(os.path.join(file_dir, "..", "..", "..", ".."))
sys.path.append(os.path.join(g_root, 'build', 'script', 'nv'))
from nv_binary import nv_begin


if __name__ == '__main__':
    #配置文件路径
    nv_config_json = os.path.join(g_root, "build", "config", "target_config", "ws63", "nv_bin_cfg", "mk_nv_bin_cfg.json")
    targets = ["acore"]
    if len(sys.argv) >= 2:
        target_name = sys.argv[1]
        if target_name == 'ws63-liteos-perf':
            nv_config_json = os.path.join(g_root, "build", "config", "target_config", "ws63", "nv_bin_cfg",
                                          "mk_nv_bin_cfg_perf.json")

    runtime_nv_cfg = nv_config_json
    fbb_output_root = os.environ.get("FBB_OUTPUT_ROOT", "").strip()
    if fbb_output_root:
        chip = os.environ.get("FBB_CHIP", "ws63").strip() or "ws63"
        core = os.environ.get("FBB_CORE", targets[0]).strip() or targets[0]
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
