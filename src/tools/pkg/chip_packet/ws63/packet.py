#!/usr/bin/env python3
# encoding=utf-8
# ============================================================================
# @brief    packet files
# ============================================================================

import os
import sys
import shutil
import subprocess
import platform
import tarfile
import json
from typing import List

PY_PATH = os.path.dirname(os.path.realpath(__file__))
sys.path.append(PY_PATH)
PKG_DIR = os.path.dirname(PY_PATH)
PKG_DIR = os.path.dirname(PKG_DIR)

from packet_create import create_sha_file
from packet_create import packet_bin

TOOLS_DIR = os.path.dirname(PKG_DIR)
SDK_DIR = os.path.dirname(TOOLS_DIR)
sys.path.append(os.path.join(SDK_DIR, "build", "script"))
sys.path.append(os.path.join(SDK_DIR, "build", "config"))
from enviroment import TargetEnvironment


def _first_existing(paths: List[str]) -> str:
    for path in paths:
        if path and os.path.exists(path):
            return path
    return paths[0] if paths else ""


def _resolve_file(paths: List[str]) -> str:
    for path in paths:
        if path and os.path.isfile(path):
            return path
    return paths[0] if paths else ""


def _load_manifest_outputs(manifest_path: str):
    if not manifest_path:
        return {}
    try:
        with open(manifest_path, "r", encoding="utf-8") as mf:
            data = json.load(mf)
    except (OSError, ValueError, TypeError):
        return {}
    outputs = data.get("outputs", [])
    if not isinstance(outputs, list):
        return {}
    resolved = {}
    for item in outputs:
        if isinstance(item, str) and os.path.isfile(item):
            resolved[os.path.basename(item)] = item
    return resolved

def get_file_size(file_path: str)->int:
    try:
        return os.stat(file_path).st_size
    except BaseException as e:
        print(e)
        exit(-1)


def create_tar(source_dir, output_filename):
    with tarfile.open(output_filename, "w") as tar:
        tar.add(source_dir)


# ws63
def make_all_in_one_packet(pack_style_str, extr_defines):
    chip = os.environ.get("FBB_CHIP", "ws63").strip() or "ws63"
    core = os.environ.get("FBB_CORE", "acore").strip() or "acore"
    caller_output_root = os.environ.get("FBB_OUTPUT_ROOT", "").strip()
    packet_manifest = os.environ.get("FBB_PACKET_INPUT_MANIFEST", "").strip()
    packet_output_manifest = os.environ.get("FBB_PACKET_OUTPUT_MANIFEST", "").strip()
    manifest_outputs = _load_manifest_outputs(packet_manifest)
    input_files = []
    output_files = []

    def add_input(path):
        if path and os.path.isfile(path):
            apath = os.path.abspath(path)
            if apath not in input_files:
                input_files.append(apath)

    def add_output(path):
        if path and os.path.isfile(path):
            apath = os.path.abspath(path)
            if apath not in output_files:
                output_files.append(apath)

    legacy_chip_root = os.path.join(SDK_DIR, "output", chip)
    legacy_acore_root = os.path.join(legacy_chip_root, core)
    if caller_output_root:
        caller_chip_root = os.path.join(os.path.abspath(caller_output_root), chip)
        caller_acore_root = os.path.join(caller_chip_root, core)
        chip_roots = [caller_chip_root, legacy_chip_root]
        acore_roots = [caller_acore_root, legacy_acore_root]
    else:
        chip_roots = [legacy_chip_root]
        acore_roots = [legacy_acore_root]

    # make all in one packet
    boot_bin_dir = _first_existing([os.path.join(root, "boot_bin") for root in acore_roots])
    param_bin_dir = _first_existing([os.path.join(root, "param_bin") for root in acore_roots])
    nv_bin_dir = _first_existing([os.path.join(root, "nv_bin") for root in acore_roots])
    efuse_bin_dir = boot_bin_dir

    # loader boot
    loadboot_bin = manifest_outputs.get("root_loaderboot_sign.bin", os.path.join(boot_bin_dir, "root_loaderboot_sign.bin"))
    add_input(loadboot_bin)
    loadboot_bx = loadboot_bin + "|0x0|0x200000|0"

    # secure stage boot
    ssb_bin = manifest_outputs.get("ssb_sign.bin", os.path.join(boot_bin_dir, "ssb_sign.bin"))
    add_input(ssb_bin)
    ssb_bx = ssb_bin + f"|0x202000|{hex(get_file_size(ssb_bin))}|1"

    # flash boot
    flashboot_bin = manifest_outputs.get("flashboot_sign.bin", os.path.join(boot_bin_dir, "flashboot_sign.bin"))
    add_input(flashboot_bin)
    flashboot_bx = flashboot_bin + f"|0x220000|{hex(get_file_size(flashboot_bin))}|1"

    # flash boot backup
    flashboot_backup_bin = manifest_outputs.get("flashboot_backup_sign.bin", os.path.join(boot_bin_dir, "flashboot_backup_sign.bin"))
    add_input(flashboot_backup_bin)
    flashboot_backup_bx = flashboot_backup_bin + f"|0x210000|{hex(get_file_size(flashboot_backup_bin))}|1"

    # params
    params_bin = manifest_outputs.get("root_params_sign.bin", os.path.join(param_bin_dir, "root_params_sign.bin"))
    add_input(params_bin)
    params_bx = params_bin + f"|0x200000|{hex(get_file_size(params_bin))}|1"

    # nv
    nv_bin = manifest_outputs.get("ws63_all_nv.bin", os.path.join(nv_bin_dir, "ws63_all_nv.bin"))
    add_input(nv_bin)
    nv_bx = nv_bin + f"|0x5FC000|0x4000|1"

    # nv backup
    nv_backup_bin = manifest_outputs.get("ws63_all_nv_factory.bin", os.path.join(nv_bin_dir, "ws63_all_nv_factory.bin"))
    add_input(nv_backup_bin)
    nv_backup_bx = nv_backup_bin + f"|0x20C000|0x4000|1"

    # hilink
    target_env = TargetEnvironment(pack_style_str)
    defines = target_env.get('defines')
    if "CONFIG_SUPPORT_HILINK_INDIE_UPGRADE" in defines:
        hilink_interim_sign_file = os.path.join(SDK_DIR, "interim_binary", "ws63", "bin", "hilink_bin", "ws63-liteos-hilink-sign.bin")
        hilink_output_sign_file = _resolve_file([os.path.join(root, "ws63-liteos-hilink", "ws63-liteos-hilink-sign.bin") for root in acore_roots])
        hilink_target_packet_dir = os.path.join(_first_existing(acore_roots), "hilink_bin")
        if not os.path.isdir(hilink_target_packet_dir):
            os.makedirs(hilink_target_packet_dir)
        if os.path.isfile(hilink_interim_sign_file):
            shutil.copy(hilink_interim_sign_file, hilink_target_packet_dir)
        if os.path.isfile(hilink_output_sign_file):
            shutil.copy(hilink_output_sign_file, hilink_target_packet_dir)
        hilink_bin_dir = hilink_target_packet_dir
        hilink_bin = os.path.join(hilink_bin_dir, "ws63-liteos-hilink-sign.bin")
        hilink_bx = hilink_bin + f"|0x3F0000|{hex(get_file_size(hilink_bin))}|1"

    # efuse bin
    efuse_bin = manifest_outputs.get("efuse_cfg.bin", os.path.join(efuse_bin_dir, "efuse_cfg.bin"))
    add_input(efuse_bin)
    efuse_bx = efuse_bin + "|0x0|0x200000|3"

    # app and rom
    app_templat_bx = '%s|0x230000|%s|1'

    # 输出目录
    fwpkg_outdir = os.path.join(_first_existing(chip_roots), "fwpkg", pack_style_str)

    # 键为target名，值为rom bin、app bin的名字
    available_targets_map = {
        'ws63-liteos-testsuite': [
            'ws63-liteos-testsuite_rom.bin',
            'ws63-liteos-testsuite-sign.bin',
        ],
        'ws63-liteos-testsuite-asic': [
            'ws63-liteos-testsuite-asic_rom.bin',
            'ws63-liteos-testsuite-asic-sign.bin',
        ],
        'ws63-freertos-testsuite': [
            'ws63-freertos-testsuite_rom.bin',
            'ws63-freertos-testsuite-sign.bin',
        ],
        'ws63-alios-testsuite': [
            'ws63-alios-testsuite_rom.bin',
            'ws63-alios-testsuite-sign.bin',
        ],
        'ws63-freertos-app': [
            'ws63-freertos-app_rom.bin',
            'ws63-freertos-app-sign.bin',
        ],
        'ws63-alios-app': [
            'ws63-alios-app_rom.bin',
            'ws63-alios-app-sign.bin',
        ],
        'ws63-liteos-bgle-all': [
            'ws63-liteos-bgle-all_rom.bin',
            'ws63-liteos-bgle-all-sign.bin',
        ],
        'ws63-liteos-bgle-all-asic': [
            'ws63-liteos-bgle-all-asic_rom.bin',
            'ws63-liteos-bgle-all-asic-sign.bin',
        ],
        'ws63-liteos-btc-only':[
            'ws63-liteos-btc-only_rom.bin',
            'ws63-liteos-btc-only-sign.bin',
        ],
        'ws63-liteos-btc-only-asic':[
            'ws63-liteos-btc-only-asic_rom.bin',
            'ws63-liteos-btc-only-asic-sign.bin',
        ],
        'ws63-liteos-gle-sparklyzer': [
            'ws63-liteos-gle-sparklyzer_rom.bin',
            'ws63-liteos-gle-sparklyzer-sign.bin',
        ],
        'ws63-freertos-btc-only': [
            'ws63-freertos-btc-only_rom.bin',
            'ws63-freertos-btc-only-sign.bin',
        ],
        'ws63-alios-btc-only': [
            'ws63-alios-btc-only_rom.bin',
            'ws63-alios-btc-only-sign.bin',
        ],
        'ws63-liteos-app': [
            'ws63-liteos-app_rom.bin',
            'ws63-liteos-app-sign.bin',
        ],
        'ws63-liteos-spi-host': [
            'ws63-liteos-spi-host_rom.bin',
            'ws63-liteos-spi-host-sign.bin',
        ],
        'ws63-liteos-spi-device': [
            'ws63-liteos-spi-device_rom.bin',
            'ws63-liteos-spi-device-sign.bin',
        ],
        'ws63-liteos-perf': [
            'ws63-liteos-perf_rom.bin',
            'ws63-liteos-perf-sign.bin',
        ],
        'ws63-liteos-app-asic': [
            'ws63-liteos-app-asic_rom.bin',
            'ws63-liteos-app-asic-sign.bin',
        ],
        'ws63-liteos-mfg': [
            'ws63-liteos-mfg_rom.bin',
            'ws63-liteos-mfg-sign.bin',
        ],
        'ws63-liteos-app-gree': [
            'ws63-liteos-app-gree.bin',
            'ws63-liteos-app-gree-sign.bin',
        ],
        'ws63-liteos-msmart': [
            'ws63-liteos-msmart_rom.bin',
            'ws63-liteos-msmart-sign.bin',
        ],
        'ws63-liteos-msmart-xts': [
            'ws63-liteos-msmart-xts_rom.bin',
            'ws63-liteos-msmart-xts-sign.bin',
        ],
        'ws63-liteos-xts': [
            'ws63-liteos-xts_rom.bin',
            'ws63-liteos-xts-sign.bin',
        ],
        'ws63-liteos-app-iot': [
            'ws63-liteos-app-iot_rom.bin',
            'ws63-liteos-app-iot-sign.bin',
        ],
        'ws63-liteos-testsuite-radar': [
            'ws63-liteos-testsuite-radar.bin',
            'ws63-liteos-testsuite-radar-sign.bin',
        ]
    }

    if pack_style_str in available_targets_map:
        # 生成前清空
        if os.path.exists(fwpkg_outdir):
            shutil.rmtree(fwpkg_outdir)
        os.makedirs(fwpkg_outdir)

        rom_name = available_targets_map[pack_style_str][0]
        app_name = available_targets_map[pack_style_str][1]
        app_raw_name = app_name.replace("-sign.bin", ".bin")

        rom_bin = _resolve_file(
            [os.path.join(root, pack_style_str, rom_name) for root in acore_roots] +
            [os.path.join(root, f"{pack_style_str}_rom.bin") for root in [caller_output_root] if root]
        )
        app_bin = _resolve_file(
            [os.path.join(root, pack_style_str, app_name) for root in acore_roots] +
            [os.path.join(root, pack_style_str, app_raw_name) for root in acore_roots] +
            [os.path.join(root, f"{pack_style_str}-sign.bin") for root in [caller_output_root] if root] +
            [os.path.join(root, f"{pack_style_str}.bin") for root in [caller_output_root] if root]
        )
        for fpath in (rom_bin, app_bin):
            if not os.path.isfile(fpath):
                print(f'[!] warning: File `{fpath}` is not exists !Skip fwpkg generate for target `{pack_style_str}` !')
                return

        app_bx = app_templat_bx % (app_bin, hex(get_file_size(app_bin)))

        if pack_style_str == 'ws63-liteos-mfg':
            output_bin_dir = _first_existing(acore_roots)
            packet_post_agvs = list()
            packet_post_agvs.append(loadboot_bx)
            packet_post_agvs.append(params_bx)
            packet_post_agvs.append(ssb_bx)
            packet_post_agvs.append(flashboot_bx)
            packet_post_agvs.append(flashboot_backup_bx)
            packet_post_agvs.append(nv_bx)
            if "PACKET_NV_FACTORY" in extr_defines:
                print("nv factory pack")
                packet_post_agvs.append(nv_backup_bx)
            app_bin = _resolve_file([
                os.path.join(output_bin_dir, "ws63-liteos-app", "ws63-liteos-app-sign.bin"),
                os.path.join(output_bin_dir, "ws63-liteos-app", "ws63-liteos-app.bin")
            ])
            app_bx = app_bin + f"|0x230000|{hex(get_file_size(app_bin))}|1"

            mfg_bin = _resolve_file([
                os.path.join(output_bin_dir, "ws63-liteos-mfg", "ws63-liteos-mfg-sign.bin"),
                os.path.join(output_bin_dir, "ws63-liteos-mfg", "ws63-liteos-mfg.bin")
            ])
            mfg_bx = mfg_bin + f"|0x470000|{hex(0x183000)}|1" # 0x183000为产测分区B区大小
            packet_post_agvs.append(app_bx)
            packet_post_agvs.append(mfg_bx)
            fpga_fwpkg = os.path.join(fwpkg_outdir, f"{pack_style_str}_all.fwpkg")
            packet_bin(fpga_fwpkg, packet_post_agvs)
            add_output(fpga_fwpkg)
            return

        packet_post_agvs = list()
        packet_post_agvs.append(loadboot_bx)
        packet_post_agvs.append(params_bx)
        packet_post_agvs.append(ssb_bx)
        packet_post_agvs.append(flashboot_bx)
        packet_post_agvs.append(flashboot_backup_bx)
        packet_post_agvs.append(nv_bx)
        if "PACKET_NV_FACTORY" in extr_defines:
            print("nv factory pack")
            packet_post_agvs.append(nv_backup_bx)
        if "CONFIG_SUPPORT_HILINK_INDIE_UPGRADE" in defines:
            packet_post_agvs.append(hilink_bx)
        packet_post_agvs.append(app_bx)

        if "SUPPORT_EFUSE" in extr_defines:
            print("efuse pack")
            packet_post_agvs.append(efuse_bx)

        double_fwpkg = is_pack_double_fwpkg(pack_style_str, extr_defines)

        if "PACKET_MFG_BIN" in extr_defines and not double_fwpkg:
            print("not packet app")
        else:
            print("packet app")
            fpga_fwpkg = os.path.join(fwpkg_outdir, f"{pack_style_str}_all.fwpkg")
            packet_bin(fpga_fwpkg, packet_post_agvs)

        if ("PACKET_MFG_BIN" in extr_defines or double_fwpkg) and "SUPPORT_EFUSE" not in extr_defines:
            print("efuse pack")
            packet_post_agvs.append(efuse_bx)

        if "PACKET_MFG_BIN" in extr_defines or double_fwpkg:
            mfg_sign_bin = _resolve_file([
                os.path.join(root, "boot_bin", "ws63-liteos-mfg-sign.bin") for root in acore_roots
            ] + [
                os.path.join(root, "boot_bin", "ws63-liteos-mfg.bin") for root in acore_roots
            ])
            if os.path.exists(mfg_sign_bin):
                mfg_bx = mfg_sign_bin + f"|0x470000|{hex(0x183000)}|1" # 0x183000为产测分区B区大小
                packet_post_agvs.append(mfg_bx)
                if double_fwpkg:
                    fpga_fwpkg = os.path.join(fwpkg_outdir, f"{pack_style_str}_mfg_all.fwpkg")
                    packet_bin(fpga_fwpkg, packet_post_agvs)
                    add_output(fpga_fwpkg)
                else:
                    fpga_fwpkg = os.path.join(fwpkg_outdir, f"{pack_style_str}_all.fwpkg")
                    packet_bin(fpga_fwpkg, packet_post_agvs)
                    add_output(fpga_fwpkg)
            else:
                print("warning: don't find ws63-liteos-mfg-sign.bin...")
        else:
            for chip_root in chip_roots:
                mfg_pkt_file = os.path.join(chip_root, "pktbin", "ws63-liteos-mfg.bin")
                if os.path.exists(mfg_pkt_file):
                    os.remove(mfg_pkt_file)

        packet_post_agvs = list()
        packet_post_agvs.append(loadboot_bx)
        packet_post_agvs.append(app_bx)
        fpga_loadapp_only_fwpkg = os.path.join(fwpkg_outdir, f"{pack_style_str}_load_only.fwpkg")
        packet_bin(fpga_loadapp_only_fwpkg, packet_post_agvs)
        add_output(fpga_loadapp_only_fwpkg)

        if "windows" in platform.system().lower():
            pktbin_base = _first_existing([root for root in chip_roots if os.path.isdir(os.path.join(root, "pktbin"))] + chip_roots)
            os.chdir(pktbin_base)
            if os.path.isdir('./pktbin'):
                create_tar('./pktbin', 'pktbin.zip')
                add_output(os.path.join(pktbin_base, 'pktbin.zip'))
        else:
            print("not windows.")
            pktbin_base = _first_existing([root for root in chip_roots if os.path.isdir(os.path.join(root, "pktbin"))] + chip_roots)
            if os.path.isdir(os.path.join(pktbin_base, "pktbin")):
                subprocess.run(["tar", "-cf", "pktbin.zip", "./pktbin"], cwd=pktbin_base)
                add_output(os.path.join(pktbin_base, 'pktbin.zip'))

        if packet_output_manifest:
            os.makedirs(os.path.dirname(os.path.abspath(packet_output_manifest)), exist_ok=True)
            manifest_inputs = list(input_files)
            if packet_manifest and os.path.isfile(packet_manifest):
                manifest_inputs.append(os.path.abspath(packet_manifest))
            with open(packet_output_manifest, "w", encoding="utf-8") as mf:
                json.dump({
                    "schema_version": "fbb.stage-manifest.v1",
                    "stage": "ws63.packet",
                    "target": pack_style_str,
                    "chip": chip,
                    "core": core,
                    "inputs": sorted(set(manifest_inputs)),
                    "command": sys.argv,
                    "outputs": sorted(set(output_files)),
                    "success": True,
                    "exit_code": 0,
                    "fwpkg_outdir": os.path.abspath(fwpkg_outdir)
                }, mf, ensure_ascii=False, indent=2)

def is_pack_double_fwpkg(pack_style_str, extr_defines):
    if 'SDK_VERSION=' in extr_defines and 'SDK_VERSION="1.10.T0"' not in extr_defines and pack_style_str == 'ws63-liteos-app':
        return True
    else:
        return False

def is_packing_files_exist(soc, pack_style_str):
    return
