import subprocess
import os
import sys
import shutil
import platform
import json
import argparse


file_dir = os.path.dirname(os.path.realpath(__file__))
g_root = os.path.realpath(os.path.join(file_dir, "..", "..", "..", "..", ".."))
sys.path.append(os.path.join(g_root, 'infra_build', 'script'))
sys.path.append(os.path.join(g_root, "infra_build", "config"))
from enviroment import TargetEnvironment
import param_packet

current_path = os.getcwd()
cwd_path = os.path.split(os.path.realpath(__file__))[0]
os.chdir(cwd_path)
if "windows" in platform.platform().lower():
    sign_tool = "../../../../../tools/bin/sign_tool/sign_tool_pltuni.exe"
else:
    sign_tool = "../../../../../tools/bin/sign_tool/sign_tool_pltuni"


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


def _load_manifest_inputs(manifest_file_path):
    if not manifest_file_path or not os.path.isfile(manifest_file_path):
        return []
    inputs = [os.path.abspath(manifest_file_path)]
    try:
        with open(manifest_file_path, "r", encoding="utf-8") as mf:
            data = json.load(mf)
    except (OSError, ValueError, TypeError):
        return inputs
    for field in ("outputs", "produced_files", "produced_bins"):
        values = data.get(field, [])
        if isinstance(values, list):
            for item in values:
                if isinstance(item, str) and os.path.exists(item):
                    inputs.append(os.path.abspath(item))
    return sorted(set(inputs))


args = _parse_args()
target_name = args.target_name_opt or args.target_name
chip = args.chip or (os.environ.get("FBB_CHIP", "ws63").strip() or "ws63")
core = args.core or (os.environ.get("FBB_CORE", "acore").strip() or "acore")
fbb_output_root = args.output_root or os.environ.get("FBB_OUTPUT_ROOT", "").strip()
input_manifest = args.input_manifest or os.environ.get("FBB_SIGN_INPUT_MANIFEST", "").strip()

if fbb_output_root:
    chip_root = os.path.join(os.path.abspath(fbb_output_root), chip)
else:
    chip_root = os.path.join(g_root, "output", chip)

out_put = os.path.join(chip_root, core)
pktbin = os.path.join(chip_root, "pktbin")
inter_bin_candidates = [
    os.path.join(chip_root, core, "boot_bin"),
    os.path.join(g_root, "interim_binary", chip, "bin", "boot_bin")
]
inter_bin = inter_bin_candidates[0]
for _candidate in inter_bin_candidates:
    if os.path.isdir(_candidate):
        inter_bin = _candidate
        break

default_manifest = os.path.join(out_put, "sign_manifest", f"{target_name}.json")
manifest_path = os.path.abspath(args.output_manifest or os.environ.get("FBB_SIGN_MANIFEST", default_manifest))
efuse_csv = "../script/efuse.csv"
boot_bin = os.path.join(out_put, "boot_bin")
mfg_bin = "../../../../../application/ws63/ws63_liteos_mfg"

generated_outputs = []


def mark_output(file_path):
    abs_file = os.path.abspath(file_path)
    if os.path.isfile(abs_file) and abs_file not in generated_outputs:
        generated_outputs.append(abs_file)


def stage_signed_output(output_dir, file_name):
    target_file = os.path.join(output_dir, file_name)
    if os.path.isfile(target_file):
        return target_file
    generated_file = os.path.join(cwd_path, file_name)
    if os.path.isfile(generated_file):
        os.makedirs(output_dir, exist_ok=True)
        shutil.copy(generated_file, target_file)
        mark_output(target_file)
        return target_file
    return target_file


def _runtime_cfg_path(cfg_name):
    return os.path.join(cwd_path, f".runtime_{cfg_name}")


def build_runtime_cfg(cfg_name, src_file=None, dst_file=None):
    cfg_path = os.path.join(cwd_path, cfg_name)
    runtime_cfg = _runtime_cfg_path(cfg_name)
    with open(cfg_path, 'r', encoding='utf-8') as cfg_file:
        lines = cfg_file.readlines()

    output_token = "../../../../../output/ws63/acore"
    normalized_out_put = out_put.replace('\\', '/')
    new_lines = []
    for line in lines:
        if src_file and line.startswith("SrcFile="):
            new_lines.append(f"SrcFile={os.path.abspath(src_file)}\n")
            continue
        if dst_file and line.startswith("DstFile="):
            new_lines.append(f"DstFile={os.path.abspath(dst_file)}\n")
            continue
        if output_token in line:
            new_lines.append(line.replace(output_token, normalized_out_put))
            continue
        new_lines.append(line)

    with open(runtime_cfg, 'w', encoding='utf-8') as runtime_file:
        runtime_file.writelines(new_lines)
    return runtime_cfg


def run_sign(cfg_mode, cfg_name, src_file=None, dst_file=None):
    runtime_cfg = build_runtime_cfg(cfg_name, src_file=src_file, dst_file=dst_file)
    try:
        return subprocess.run([sign_tool, cfg_mode, runtime_cfg], stdout=subprocess.DEVNULL)
    finally:
        if os.path.exists(runtime_cfg):
            os.remove(runtime_cfg)

def merge(file_first, file_second, file_out):
    if "windows" in platform.platform().lower():
        out_path = os.path.normpath(os.path.realpath(file_out)).rsplit('\\' , 1)[0]
    else:
        out_path = os.path.normpath(os.path.realpath(file_out)).rsplit('/' , 1)[0]
    print("merge out path: ", out_path)
    if not os.path.exists(out_path):
        os.makedirs(out_path)
    ret = open(file_out, 'wb')
    with open(file_first, 'rb') as file_1:
        for i in file_1:
            ret.write(i)
    with open(file_second, 'rb') as file_2:
        for i in file_2:
            ret.write(i)
    ret.close()


def move_file(src_path, dst_path, file_name):
    src_file = os.path.join(src_path, file_name)
    os.makedirs(dst_path, exist_ok=True)
    dst_file = os.path.join(dst_path, file_name)
    shutil.move(src_file, dst_file)
    mark_output(dst_file)


def sign_app(file_path, type, cfg_name, dst_file=None):
    if os.path.isfile(file_path):
        print("sign name: ", file_path)
        dd64c(file_path)
        if dst_file is None:
            dst_file = file_path.replace(".bin", "-sign.bin")
        ret = run_sign(type, cfg_name, src_file=file_path, dst_file=dst_file)
        if ret.returncode == 0:
            print(file_path, " generated successfully!!!")
            sign_bin = dst_file
            mark_output(sign_bin)
        else:
            print(file_path, " generated failed!!!")
        shutil.copy(file_path, pktbin)
        mark_output(os.path.join(pktbin, os.path.basename(file_path)))
    else:
        pass


def generate_fill_bin(file_path, size):
    with open(file_path, 'wb') as f:
        f.write(bytes([0xFF] * size))


def dd64c(input_file_path):
    file_size = os.path.getsize(input_file_path)
    print(input_file_path, "size: ", file_size)
    if file_size % 64 != 0:
        max_size = int((file_size / 64)+1) * 64
        if file_size < max_size:
            file_content = open(input_file_path, 'ab')
            file_content.write(bytes([0] * int(max_size - file_size)))


if os.path.exists(pktbin):
    shutil.rmtree(pktbin)
os.makedirs(pktbin)

# generate params.bin
params_cmd = ["../param_sector/param_sector.json", "params.bin"]
if target_name == "ws63-liteos-app-iot" or target_name == "ws63-liteos-hilink":
    target_env = TargetEnvironment(target_name)
    defines = target_env.get('defines')
    if "CONFIG_SUPPORT_HILINK_INDIE_UPGRADE" in defines:
        params_cmd = ["../param_sector/param_sector_hilink_indie_upgrade.json", "params.bin"]
if target_name == "ws63-liteos-msmart" or target_name == "ws63-liteos-msmart-xts":
    params_cmd = ["../param_sector/param_sector_ms.json", "params.bin"]

print("generate params.bin...")
param_packet.gen_flash_part_bin(params_cmd[0], params_cmd[1])
if os.path.isfile("params.bin"):
    dd64c("params.bin")
    print("params.bin generate successfully!!!")

    # generate params_sign.bin
    param_bin_ecc_cmd = [sign_tool, "0", "param_bin_ecc.cfg"]
    ret = run_sign("0", "param_bin_ecc.cfg")
    if ret.returncode == 0:
        print("params_sign.bin generate successfully!!!")
    else:
        print("params_sign.bin generate failed!!!")

    # generate root public key
    root_pubk_cmd = [sign_tool, "1", "root_pubk.cfg"]
    ret = run_sign("1", "root_pubk.cfg")
    if ret.returncode == 0:
        print("root_pubk.bin generate successfully!!!")
    else:
        generate_fill_bin("root_pubk.bin", 0x80)
        print("generate fill root_pubk.bin")

    # packet root public key and param.bin
    merge("root_pubk.bin", "params_sign.bin", "root_params_sign.bin")
    print("root_params_sign.bin generate successfully!!!")
    move_file(cwd_path, os.path.join(out_put, "param_bin"), "root_params_sign.bin")

if not os.path.isdir(boot_bin):
    shutil.copytree(inter_bin, boot_bin)
    generated_outputs.append(os.path.abspath(boot_bin))

_interim_ssb = os.path.join(inter_bin, "ssb.bin")
_boot_ssb = os.path.join(boot_bin, "ssb.bin")
if os.path.isfile(_interim_ssb):
    if os.path.abspath(_interim_ssb) != os.path.abspath(_boot_ssb):
        shutil.copy(_interim_ssb, boot_bin)
    mark_output(_boot_ssb)

if os.path.isfile(os.path.join(mfg_bin, "ws63-liteos-mfg.bin")):
    shutil.copy(os.path.join(mfg_bin, "ws63-liteos-mfg.bin"), boot_bin)
    mark_output(os.path.join(boot_bin, "ws63-liteos-mfg.bin"))

#sign ssb
if os.path.isfile(os.path.join(out_put, "ws63-ssb/ssb.bin")):
    dd64c(os.path.join(out_put, "ws63-ssb/ssb.bin"))
    shutil.copy(os.path.join(out_put, "ws63-ssb/ssb.bin"), pktbin)
    ret1 = run_sign("0", "ssb_bin_ecc.cfg", src_file=os.path.join(out_put, "ws63-ssb", "ssb.bin"), dst_file=os.path.join(out_put, "ws63-ssb", "ssb_sign.bin"))
    if ret1.returncode == 0:
        ssb_sign_file = stage_signed_output(os.path.join(out_put, "ws63-ssb"), "ssb_sign.bin")
        print("ssb_sign.bin generated successfully!!!")
        if os.path.isfile(ssb_sign_file):
            shutil.copy(ssb_sign_file, boot_bin)
            mark_output(os.path.join(boot_bin, "ssb_sign.bin"))
        else:
            print("warning: ssb_sign.bin is missing, skip copy to boot_bin")
    else:
        print("ssb_sign.bin generated failed!!!")

#sign interim ssb
if os.path.isfile(os.path.join(inter_bin, 'ssb.bin')):
    jug_ssb = False
    if not os.path.isfile(os.path.join(out_put, "ws63-ssb/ssb.bin")):
        os.makedirs(os.path.join(out_put, 'ws63-ssb'))
        shutil.copy(os.path.join(inter_bin, 'ssb.bin'), os.path.join(out_put, "ws63-ssb"))
        sign_app(
            os.path.join(out_put, "ws63-ssb/ssb.bin"),
            "0",
            "ssb_bin_ecc.cfg",
            os.path.join(out_put, "ws63-ssb", "ssb_sign.bin")
        )
        jug_ssb = True
    if os.path.isfile(os.path.join(out_put, "ws63-ssb/ssb_sign.bin")):
        shutil.copy(os.path.join(out_put, "ws63-ssb/ssb_sign.bin"), boot_bin)
        print("ssb_sign.bin generated successfully!!!")
        mark_output(os.path.join(boot_bin, "ssb_sign.bin"))
    else:
        print("warning: ssb_sign.bin is missing, skip copy to boot_bin")
    if jug_ssb:
        shutil.rmtree(os.path.join(out_put, 'ws63-ssb'))

#sign flash boot
if os.path.isfile(os.path.join(out_put, "ws63-flashboot/flashboot.bin")):
    dd64c(os.path.join(out_put, "ws63-flashboot/flashboot.bin"))
    shutil.copy(os.path.join(out_put, "ws63-flashboot/flashboot.bin"), pktbin)
    ret1 = run_sign("0", "flash_bin_ecc.cfg", src_file=os.path.join(out_put, "ws63-flashboot", "flashboot.bin"), dst_file=os.path.join(out_put, "ws63-flashboot", "flashboot_sign.bin"))
    ret2 = run_sign("0", "flash_backup_bin_ecc.cfg", src_file=os.path.join(out_put, "ws63-flashboot", "flashboot.bin"), dst_file=os.path.join(out_put, "ws63-flashboot", "flashboot_backup_sign.bin"))
    if ret1.returncode == 0 and ret2.returncode == 0:
        stage_signed_output(os.path.join(out_put, "ws63-flashboot"), "flashboot_sign.bin")
        stage_signed_output(os.path.join(out_put, "ws63-flashboot"), "flashboot_backup_sign.bin")
        print("flash_sign.bin generated successfully!!!")
    else:
        print("flash_sign.bin generated failed!!!")

if os.path.isfile(os.path.join(out_put, "ws63-flashboot/flashboot.bin")):
    shutil.copy(os.path.join(out_put, "ws63-flashboot/flashboot.bin"), boot_bin)
    flash_sign_file = stage_signed_output(os.path.join(out_put, "ws63-flashboot"), "flashboot_sign.bin")
    flash_backup_sign_file = stage_signed_output(os.path.join(out_put, "ws63-flashboot"), "flashboot_backup_sign.bin")
    if os.path.isfile(flash_sign_file):
        shutil.copy(flash_sign_file, boot_bin)
    else:
        print("warning: flashboot_sign.bin is missing, skip copy to boot_bin")
    if os.path.isfile(flash_backup_sign_file):
        shutil.copy(flash_backup_sign_file, boot_bin)
    else:
        print("warning: flashboot_backup_sign.bin is missing, skip copy to boot_bin")
    mark_output(os.path.join(boot_bin, "flashboot.bin"))
    mark_output(os.path.join(boot_bin, "flashboot_sign.bin"))
    mark_output(os.path.join(boot_bin, "flashboot_backup_sign.bin"))

if os.path.isfile(os.path.join(out_put, "ws63-ate-flash", "ws63-ate-flash.bin")):
    dd64c(os.path.join(out_put, "ws63-ate-flash", "ws63-ate-flash.bin"))
    ret1 = run_sign("0", "flash_htol_bin_ecc.cfg")
    if ret1.returncode == 0:
        print("ws63_ate_flash.bin generated successfully!!!")
    else:
        print("ws63_ate_flash.bin generated failed!!!")

if os.path.isfile(os.path.join(out_put, "ws63-loaderboot", "loaderboot.bin")):
    dd64c(os.path.join(out_put, "ws63-loaderboot", "loaderboot.bin"))
    shutil.copy(os.path.join(out_put, "ws63-loaderboot", "loaderboot.bin"), pktbin)
    ret1 = run_sign("0", "loaderboot_bin_ecc.cfg", src_file=os.path.join(out_put, "ws63-loaderboot", "loaderboot.bin"), dst_file=os.path.join(cwd_path, "loaderboot_sign.bin"))
    if ret1.returncode == 0:
        print("loaderboot_sign.bin generated successfully!!!")
    else:
        print("loaderboot_sign.bin generated failed!!!")
    merge("root_pubk.bin", "loaderboot_sign.bin", os.path.join(out_put, "ws63-loaderboot", "root_loaderboot_sign.bin"))
    shutil.copy(os.path.join(out_put, "ws63-loaderboot/root_loaderboot_sign.bin"), boot_bin)
    mark_output(os.path.join(out_put, "ws63-loaderboot", "root_loaderboot_sign.bin"))
    mark_output(os.path.join(boot_bin, "root_loaderboot_sign.bin"))
    print("root_loaderboot_sign.bin generated successfully!!!")
    os.remove("loaderboot_sign.bin")

#sign loaderboot.bin interim
if os.path.isfile(os.path.join(inter_bin, 'loaderboot.bin')):
    jug_loaderboot = False
    if not os.path.isfile(os.path.join(out_put, "ws63-loaderboot/loaderboot.bin")):
        os.makedirs(os.path.join(out_put, 'ws63-loaderboot'))
        jug_loaderboot = True
        shutil.copy(os.path.join(inter_bin, 'loaderboot.bin'), os.path.join(out_put, "ws63-loaderboot"))
        sign_app(
            os.path.join(out_put, "ws63-loaderboot/loaderboot.bin"),
            "0",
            "loaderboot_bin_ecc.cfg",
            os.path.join(cwd_path, "loaderboot_sign.bin")
        )
        if(os.path.isfile("loaderboot_sign.bin")):
            print("loaderboot_sign.bin generated successfully!!!")
            merge("root_pubk.bin", 'loaderboot_sign.bin', os.path.join(boot_bin, 'root_loaderboot_sign.bin'))
            mark_output(os.path.join(boot_bin, "root_loaderboot_sign.bin"))
            print("root_loaderboot_sign.bin generated successfully!!!")
        os.remove('loaderboot_sign.bin')
    if jug_loaderboot:
        shutil.rmtree(os.path.join(out_put, "ws63-loaderboot"))


# sign app
sign_app(os.path.join(out_put, "ws63-liteos-testsuite/ws63-liteos-testsuite.bin"), "0", "testsuit_app_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-liteos-app/ws63-liteos-app.bin"), "0", "liteos_app_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-liteos-spi-host/ws63-liteos-spi-host.bin"), "0", "liteos_spi_host_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-liteos-spi-device/ws63-liteos-spi-device.bin"), "0", "liteos_spi_device_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-liteos-hilink/ws63-liteos-hilink.bin"), "0", "liteos_hilink_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-liteos-app-gree/ws63-liteos-app-gree.bin"), "0", "liteos_app_gree_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-liteos-msmart/ws63-liteos-msmart.bin"), "0", "liteos_msmart_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-liteos-msmart-xts/ws63-liteos-msmart-xts.bin"), "0", "liteos_msmart_xts_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-liteos-xts/ws63-liteos-xts.bin"), "0", "liteos_xts_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-liteos-app-iot/ws63-liteos-app-iot.bin"), "0", "liteos_app_iot_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-liteos-btc-only/ws63-liteos-btc-only.bin"), "0", "btc_only_app_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-liteos-btc-only-asic/ws63-liteos-btc-only-asic.bin"), "0", "liteos_btc_only_asic_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-liteos-gle-sparklyzer/ws63-liteos-gle-sparklyzer.bin"), "0", "sparklyzer_btc_only_app_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-liteos-mfg/ws63-liteos-mfg.bin"), "0", "liteos_mfg_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-liteos-perf/ws63-liteos-perf.bin"), "0", "liteos_perf_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-liteos-app-asic/ws63-liteos-app-asic.bin"), "0", "liteos_app_asic_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-freertos-testsuite/ws63-freertos-testsuite.bin"), "0", "freertos_testsuit_app_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-freertos-app/ws63-freertos-app.bin"), "0", "freertos_app_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-freertos-wifi-only/ws63-freertos-wifi-only.bin"), "0", "freertos_wifi_only_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-freertos-btc-only/ws63-freertos-btc-only.bin"), "0", "freertos_btc_only_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-alios-app/ws63-alios-app.bin"), "0", "alios_app_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-alios-testsuite/ws63-alios-testsuite.bin"), "0", "alios_testsuit_app_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-alios-btc-only/ws63-alios-btc-only.bin"), "0", "alios_btc_only_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-liteos-bgle-all/ws63-liteos-bgle-all.bin"), "0", "liteos_bgle_all_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-liteos-bgle-all-asic/ws63-liteos-bgle-all-asic.bin"), "0", "liteos_bgle_all_asic_bin_ecc.cfg")

sign_app(os.path.join(out_put, "ws63-liteos-testsuite-radar/ws63-liteos-testsuite-radar.bin"), "0", "liteos_testsuite_radar_bin_ecc.cfg")

sign_app(os.path.join(boot_bin, "ws63-liteos-mfg.bin"), "0", "liteos_mfg_bin_factory_ecc.cfg")

move_file(cwd_path, os.path.join(out_put, "param_bin"), "params.bin")
# clean middle files
if os.path.exists("params_sign.bin"):
    os.remove("params_sign.bin")
if os.path.exists("root_pubk.bin"):
    os.remove("root_pubk.bin")

if os.path.isfile(os.path.join(out_put, "ws63-liteos-app", "ws63-liteos-app.bin")):
    shutil.copy(os.path.join(out_put, "ws63-liteos-app", "ws63-liteos-app.bin"), pktbin)

if os.path.isfile(os.path.join(out_put, "ws63-liteos-hilink", "ws63-liteos-hilink.bin")):
    shutil.copy(os.path.join(out_put, "ws63-liteos-hilink", "ws63-liteos-hilink.bin"), pktbin)

if os.path.isfile(os.path.join(inter_bin, "ssb.bin")):
    shutil.copy(os.path.join(inter_bin, "ssb.bin"), pktbin)

if os.path.isfile(os.path.join(inter_bin, "flashboot.bin")):
    shutil.copy(os.path.join(inter_bin, "flashboot.bin"), pktbin)

if os.path.isfile(os.path.join(inter_bin, "loaderboot.bin")):
    shutil.copy(os.path.join(inter_bin, "loaderboot.bin"), pktbin)

if os.path.isfile(efuse_csv):
    shutil.copy(efuse_csv, pktbin)

if os.path.isfile(os.path.join(out_put, "param_bin", "params.bin")):
    shutil.copy(os.path.join(out_put, "param_bin", "params.bin"), pktbin)
    mark_output(os.path.join(pktbin, "params.bin"))

if os.path.isfile(os.path.join(out_put, "nv_bin", "ws63_all_nv.bin")):
    shutil.copy(os.path.join(out_put, "nv_bin", "ws63_all_nv.bin"), pktbin)
    mark_output(os.path.join(pktbin, "ws63_all_nv.bin"))

if os.path.isfile(os.path.join(out_put, "nv_bin", "ws63_all_nv_factory.bin")):
    shutil.copy(os.path.join(out_put, "nv_bin", "ws63_all_nv_factory.bin"), pktbin)
    mark_output(os.path.join(pktbin, "ws63_all_nv_factory.bin"))

os.makedirs(os.path.dirname(manifest_path), exist_ok=True)
manifest_data = {
    "schema_version": "fbb.stage-manifest.v1",
    "stage": "ws63.sign",
    "target": target_name,
    "chip": chip,
    "core": core,
    "inputs": sorted(set(_load_manifest_inputs(input_manifest))),
    "command": sys.argv,
    "success": True,
    "exit_code": 0,
    "output_root": out_put,
    "pktbin": pktbin,
    "outputs": sorted(generated_outputs),
    "produced_files": sorted(generated_outputs)
}
with open(manifest_path, "w", encoding="utf-8") as manifest_file:
    json.dump(manifest_data, manifest_file, indent=2, ensure_ascii=False)

os.chdir(current_path)
