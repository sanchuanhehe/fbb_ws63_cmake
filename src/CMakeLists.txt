#===============================================================================
# @brief    cmake entry
# Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2022-2022. All rights reserved.
#===============================================================================
cmake_minimum_required(VERSION 3.14.1)
set(CMAKE_SYSTEM_NAME "Generic")

find_package(Python3 COMPONENTS Interpreter REQUIRED)

set(FBB_EXTRA_DEFINES "" CACHE STRING "Extra defines passed to packaging scripts")

if(NOT DEFINED PY_PATH OR "${PY_PATH}" STREQUAL "")
    set(PY_PATH ${Python3_EXECUTABLE})
endif()

if(DEFINED FBB_TARGET AND NOT "${FBB_TARGET}" STREQUAL "")
    set(FBB_OUTPUT_ROOT "${CMAKE_BINARY_DIR}")

    set(_FBB_GEN_DIR "${CMAKE_BINARY_DIR}/fbb_generated/${FBB_TARGET}")
    set(_FBB_TARGET_JSON "${_FBB_GEN_DIR}/target_env.json")
    set(_FBB_TARGET_CMAKE "${_FBB_GEN_DIR}/target_env.cmake")

    execute_process(
        COMMAND ${PY_PATH} ${CMAKE_CURRENT_LIST_DIR}/build/script/export_target_env.py
            --target ${FBB_TARGET}
            --json-out ${_FBB_TARGET_JSON}
            --cmake-out ${_FBB_TARGET_CMAKE}
            --output-root ${FBB_OUTPUT_ROOT}
        WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
        RESULT_VARIABLE FBB_EXPORT_RESULT
    )

    if(NOT FBB_EXPORT_RESULT EQUAL 0)
        message(FATAL_ERROR "Failed to export target metadata for target: ${FBB_TARGET}")
    endif()

    include(${_FBB_TARGET_CMAKE})
    set(ENV{FBB_OUTPUT_ROOT} "${CMAKE_BINARY_DIR}")

    if(DEFINED FBB_BUILD_LEVEL AND NOT "${FBB_BUILD_LEVEL}" STREQUAL "")
        set(BUILD_LEVEL ${FBB_BUILD_LEVEL})
    endif()

    set(FBB_CONTRACT_FILE "${CMAKE_BINARY_DIR}/fbb_contract.json")
    execute_process(
        COMMAND ${PY_PATH} ${CMAKE_CURRENT_LIST_DIR}/build/script/export_build_contract.py
            --target-env-json ${_FBB_TARGET_JSON}
            --cmake-binary-dir ${CMAKE_BINARY_DIR}
            --out ${FBB_CONTRACT_FILE}
        WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
        RESULT_VARIABLE FBB_CONTRACT_RESULT
    )

    if(NOT FBB_CONTRACT_RESULT EQUAL 0)
        message(FATAL_ERROR "Failed to export build contract for target: ${FBB_TARGET}")
    endif()
endif()

if(DEFINED ENV{build_ws63_sdk_open})
    set(build_lib true)
else()
    set(build_lib false)
endif()

if(NOT DEFINED CHIP)
    message(FATAL_ERROR "Chip is not defined ")
endif()

set(Python3_EXECUTABLE ${PY_PATH})
find_program(CCACHE_FOUND ccache)
if(CCACHE_FOUND)
    set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ccache)
endif(CCACHE_FOUND)

# default hso module_name & AUTO_DEF_FILE_ID & AUTO_DEF_MODULE_ID, redefine these var in sub cmake file will
# override these value just in sub directory but not others
set(MODULE_NAME "pf")
set(AUTO_DEF_FILE_ID TRUE)
set(AUTO_DEF_MODULE_ID TRUE)

set(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)
get_filename_component(ROOT_DIR  "${PROJECT_SOURCE_DIR}" ABSOLUTE)
set(CMAKE_DIR "${ROOT_DIR}/build/cmake")
set(BIN_DIR   "${ROOT_DIR}/interim_binary")

include("${CMAKE_DIR}/build_function.cmake")
include("${CMAKE_DIR}/global_variable.cmake")
include("${CMAKE_DIR}/build_script.cmake")
include("${CMAKE_DIR}/build_command.cmake")
include("${CMAKE_DIR}/build_hso_database.cmake")
include("${CMAKE_DIR}/build_component.cmake")
include("${CMAKE_DIR}/build_sdk.cmake")

include_directories(${ROOT_DIR}/kernel/liteos/liteos_v208.5.0/Huawei_LiteOS/targets/ws63/include)

if(EXISTS "${ROOT_DIR}/kernel/liteos/liteos_v208.5.0/${TARGET_COMMAND}")
    set(build_ws63_sdk_open true)
endif ()

if(${BUILD_TYPE} STREQUAL "UT")
    KCONFIG_GET_PARAMS("${ROOT_DIR}/build/menuconfig/test/platform/ut.config")
    include("${CMAKE_DIR}/build_ut.cmake")
    return()
endif()

if(${BUILD_TYPE} STREQUAL "FUZZ")
    KCONFIG_GET_PARAMS("${ROOT_DIR}/build/menuconfig/test/platform/ut.config")
    include("${CMAKE_DIR}/build_fuzz.cmake")
    return()
endif()

project(${CHIP}_CFBB C ASM CXX)
set(CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES "")

if(EXISTS ${CMAKE_BINARY_DIR}/auto_gen_libfunc.lds)
    file(REMOVE ${CMAKE_BINARY_DIR}/auto_gen_libfunc.lds)
endif()

set(TARGET_COMPONENT "${RAM_COMPONENT}" "${ROM_COMPONENT}")
set(TARGET_NAME ${BIN_NAME})
file(WRITE ${PROJECT_BINARY_DIR}/temp/__null___.c "int __null___(void) {return 0;}")
add_executable(${BIN_NAME} ${PROJECT_BINARY_DIR}/temp/__null___.c)
set_target_properties(${BIN_NAME} PROPERTIES RUNTIME_OUTPUT_NAME ${BIN_NAME}.elf)
target_compile_options(${BIN_NAME} PRIVATE "${CCFLAGS}")

include("${CMAKE_DIR}/build_rom_callback.cmake")
if(${BUILD_ROM_CALLBACK})
    build_rom_callback()
endif()

set(KCONFIG_PATH "${ROOT_DIR}/build/config/target_config/${CHIP}/menuconfig/${CORE}/${BUILD_TARGET_NAME}.config")
if(EXISTS ${KCONFIG_PATH})
    KCONFIG_GET_PARAMS(${KCONFIG_PATH})
    set(USE_KCONFIG True)
endif()

if(DEFINED FBB_TARGET AND NOT "${FBB_TARGET}" STREQUAL "")
    add_custom_command(
        OUTPUT ${FBB_CONTRACT_FILE}
        COMMAND ${PY_PATH} ${ROOT_DIR}/build/script/export_build_contract.py
            --target-env-json ${_FBB_TARGET_JSON}
            --cmake-binary-dir ${CMAKE_BINARY_DIR}
            --out ${FBB_CONTRACT_FILE}
        WORKING_DIRECTORY ${ROOT_DIR}
        VERBATIM
    )
    add_custom_target(build-contract
        DEPENDS ${FBB_CONTRACT_FILE}
    )

    set(_KCONFIG_HEADER "${PROJECT_BINARY_DIR}/mconfig.h")
    execute_process(
        COMMAND ${Python3_EXECUTABLE} ${ROOT_DIR}/build/script/usr_config.py --command savemenuconfig --chip ${CHIP} --core ${CORE} --target ${PKG_TARGET_NAME} --output ${PROJECT_BINARY_DIR}
        WORKING_DIRECTORY ${ROOT_DIR}
        RESULT_VARIABLE _KCONFIG_HEADER_RESULT
    )
    if(NOT _KCONFIG_HEADER_RESULT EQUAL 0)
        message(FATAL_ERROR "Failed to generate kconfig header: ${_KCONFIG_HEADER}")
    endif()
    add_custom_command(
        OUTPUT ${_KCONFIG_HEADER}
        COMMAND ${Python3_EXECUTABLE} ${ROOT_DIR}/build/script/usr_config.py --command savemenuconfig --chip ${CHIP} --core ${CORE} --target ${PKG_TARGET_NAME} --output ${PROJECT_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E touch ${_KCONFIG_HEADER}
        WORKING_DIRECTORY ${ROOT_DIR}
        DEPENDS ${ROOT_DIR}/build/script/usr_config.py
        VERBATIM
    )

    set(_KCONFIG_MENUCONFIG_STAMP "${PROJECT_BINARY_DIR}/kconfig_menuconfig.stamp")
    add_custom_command(
        OUTPUT ${_KCONFIG_MENUCONFIG_STAMP}
        COMMAND ${Python3_EXECUTABLE} ${ROOT_DIR}/build/script/usr_config.py --command menuconfig --chip ${CHIP} --core ${CORE} --target ${PKG_TARGET_NAME} --output ${PROJECT_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E touch ${_KCONFIG_MENUCONFIG_STAMP}
        WORKING_DIRECTORY ${ROOT_DIR}
        DEPENDS ${ROOT_DIR}/build/script/usr_config.py
        USES_TERMINAL
        VERBATIM
    )
    add_custom_target(kconfig-menuconfig
        DEPENDS ${_KCONFIG_MENUCONFIG_STAMP}
    )

    set(_KCONFIG_DEFCONFIG_STATE "${PROJECT_BINARY_DIR}/kconfig_state/defconfig.json")
    add_custom_command(
        OUTPUT ${_KCONFIG_DEFCONFIG_STATE}
        COMMAND ${CMAKE_COMMAND} -E make_directory ${PROJECT_BINARY_DIR}/kconfig_state
        COMMAND ${Python3_EXECUTABLE} ${ROOT_DIR}/build/script/usr_config.py --command defconfig --chip ${CHIP} --core ${CORE} --target ${PKG_TARGET_NAME} --output ${PROJECT_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E touch ${_KCONFIG_DEFCONFIG_STATE}
        WORKING_DIRECTORY ${ROOT_DIR}
        DEPENDS ${ROOT_DIR}/build/script/usr_config.py
        USES_TERMINAL
        VERBATIM
    )
    add_custom_target(kconfig-defconfig
        DEPENDS ${_KCONFIG_DEFCONFIG_STATE}
    )

    set(_KCONFIG_RELOAD_STATE "${PROJECT_BINARY_DIR}/kconfig_state/reload.json")
    add_custom_command(
        OUTPUT ${_KCONFIG_RELOAD_STATE}
        COMMAND ${CMAKE_COMMAND} -E make_directory ${PROJECT_BINARY_DIR}/kconfig_state
        COMMAND ${Python3_EXECUTABLE} ${ROOT_DIR}/build/script/usr_config.py --command reloadconfig --chip ${CHIP} --core ${CORE} --target ${PKG_TARGET_NAME} --output ${PROJECT_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E touch ${_KCONFIG_RELOAD_STATE}
        WORKING_DIRECTORY ${ROOT_DIR}
        DEPENDS ${ROOT_DIR}/build/script/usr_config.py
        USES_TERMINAL
        VERBATIM
    )
    add_custom_target(kconfig-reload
        DEPENDS ${_KCONFIG_RELOAD_STATE}
    )

    add_custom_target(kconfig-header
        DEPENDS ${_KCONFIG_HEADER}
    )
    if(TARGET ${TARGET_NAME})
        add_dependencies(${TARGET_NAME} kconfig-header)
    endif()

    if(DEFINED PACKET AND PACKET)
        set(_PREPACKAGE_OUT_ROOT "${OUTPUT_ROOT}/${CHIP}/${CORE}")
        set(_PREPACKAGE_BOOT_MANIFEST "${_PREPACKAGE_OUT_ROOT}/package_manifest/${TARGET_NAME}.json")
        set(_PREPACKAGE_FLASHBOOT_BIN "${_PREPACKAGE_OUT_ROOT}/ws63-flashboot/flashboot.bin")
        set(_PREPACKAGE_LOADERBOOT_BIN "${_PREPACKAGE_OUT_ROOT}/ws63-loaderboot/loaderboot.bin")
        set(_FLASHBOOT_BUILD_DIR "${PROJECT_BINARY_DIR}/_deps/ws63-flashboot")
        set(_LOADERBOOT_BUILD_DIR "${PROJECT_BINARY_DIR}/_deps/ws63-loaderboot")
        add_custom_command(
            OUTPUT ${_PREPACKAGE_BOOT_MANIFEST} ${_PREPACKAGE_FLASHBOOT_BIN} ${_PREPACKAGE_LOADERBOOT_BIN}
            COMMAND ${CMAKE_COMMAND} -E make_directory ${_FLASHBOOT_BUILD_DIR}
            COMMAND ${CMAKE_COMMAND} -S ${ROOT_DIR} -B ${_FLASHBOOT_BUILD_DIR} -G "${CMAKE_GENERATOR}" -DFBB_TARGET=ws63-flashboot -DFBB_BUILD_LEVEL=${FBB_BUILD_LEVEL}
            COMMAND ${CMAKE_COMMAND} --build ${_FLASHBOOT_BUILD_DIR} --target kconfig-header
            COMMAND ${CMAKE_COMMAND} --build ${_FLASHBOOT_BUILD_DIR} --target all
            COMMAND ${CMAKE_COMMAND} -E make_directory ${_PREPACKAGE_OUT_ROOT}/ws63-flashboot
            COMMAND ${CMAKE_COMMAND} -E copy_if_different ${_FLASHBOOT_BUILD_DIR}/flashboot.bin ${_PREPACKAGE_FLASHBOOT_BIN}
            COMMAND ${CMAKE_COMMAND} -E make_directory ${_LOADERBOOT_BUILD_DIR}
            COMMAND ${CMAKE_COMMAND} -S ${ROOT_DIR} -B ${_LOADERBOOT_BUILD_DIR} -G "${CMAKE_GENERATOR}" -DFBB_TARGET=ws63-loaderboot -DFBB_BUILD_LEVEL=${FBB_BUILD_LEVEL}
            COMMAND ${CMAKE_COMMAND} --build ${_LOADERBOOT_BUILD_DIR} --target kconfig-header
            COMMAND ${CMAKE_COMMAND} --build ${_LOADERBOOT_BUILD_DIR} --target all
            COMMAND ${CMAKE_COMMAND} -E make_directory ${_PREPACKAGE_OUT_ROOT}/ws63-loaderboot
            COMMAND ${CMAKE_COMMAND} -E copy_if_different ${_LOADERBOOT_BUILD_DIR}/loaderboot.bin ${_PREPACKAGE_LOADERBOOT_BIN}
            COMMAND ${CMAKE_COMMAND} -E env
                    FBB_OUTPUT_ROOT=${OUTPUT_ROOT}
                    FBB_CHIP=${CHIP}
                    FBB_CORE=${CORE}
                    FBB_SIGN_MANIFEST=${_PREPACKAGE_BOOT_MANIFEST}
                    ${Python3_EXECUTABLE} ${ROOT_DIR}/build/config/target_config/${CHIP}/sign_config/params_and_bin_sign.py ${TARGET_NAME}
            WORKING_DIRECTORY ${ROOT_DIR}
            DEPENDS ${TARGET_NAME} GENERAT_BIN ${ROOT_DIR}/build/config/target_config/${CHIP}/sign_config/params_and_bin_sign.py
            VERBATIM
        )
        add_custom_target(prepackage-bootloaders DEPENDS ${_PREPACKAGE_BOOT_MANIFEST} ${_PREPACKAGE_FLASHBOOT_BIN} ${_PREPACKAGE_LOADERBOOT_BIN})

        set(_FWPKG_DEPS prepackage-bootloaders ${TARGET_NAME} GENERAT_BIN)
        if(TARGET WS53_GENERAT_SIGNBIN)
            list(APPEND _FWPKG_DEPS WS53_GENERAT_SIGNBIN)
        endif()

        set(_FWPKG_OUT_DIR "${OUTPUT_ROOT}/${CHIP}/fwpkg/${PKG_TARGET_NAME}")
        set(_FWPKG_ALL "${_FWPKG_OUT_DIR}/${PKG_TARGET_NAME}_all.fwpkg")
        set(_FWPKG_LOAD_ONLY "${_FWPKG_OUT_DIR}/${PKG_TARGET_NAME}_load_only.fwpkg")
        set(_FWPKG_MANIFEST "${_FWPKG_OUT_DIR}/${PKG_TARGET_NAME}_packet_manifest.json")
        add_custom_command(
            OUTPUT ${_FWPKG_ALL} ${_FWPKG_LOAD_ONLY}
            COMMAND ${CMAKE_COMMAND} -E env
                    FBB_OUTPUT_ROOT=${OUTPUT_ROOT}
                    FBB_CHIP=${CHIP}
                    FBB_CORE=${CORE}
                FBB_PACKET_INPUT_MANIFEST=${_PREPACKAGE_BOOT_MANIFEST}
                FBB_PACKET_OUTPUT_MANIFEST=${_FWPKG_MANIFEST}
                    ${Python3_EXECUTABLE} ${ROOT_DIR}/tools/pkg/packet.py ${CHIP} ${PKG_TARGET_NAME} "${FBB_EXTRA_DEFINES}"
            WORKING_DIRECTORY ${ROOT_DIR}
            DEPENDS ${_FWPKG_DEPS} ${ROOT_DIR}/tools/pkg/packet.py ${ROOT_DIR}/tools/pkg/chip_packet/ws63/packet.py
            BYPRODUCTS ${OUTPUT_ROOT}/${CHIP}/fwpkg ${_FWPKG_MANIFEST}
            VERBATIM
        )
        add_custom_target(package-fwpkg DEPENDS ${_FWPKG_ALL} ${_FWPKG_LOAD_ONLY})
    endif()

    if(DEFINED UPG_PKG AND NOT "${UPG_PKG}" STREQUAL "")
        set(_FOTA_SCRIPT ${ROOT_DIR}/build/config/target_config/${CHIP}/build_${CHIP}_update.py)
        if(EXISTS ${_FOTA_SCRIPT})
            set(_FOTA_MANIFEST "${OUTPUT_ROOT}/${CHIP}/upgrade/fota_manifest/${PKG_TARGET_NAME}.json")
            add_custom_command(
                OUTPUT ${_FOTA_MANIFEST}
                COMMAND ${CMAKE_COMMAND} -E env
                        FBB_OUTPUT_ROOT=${OUTPUT_ROOT}
                        FBB_CHIP=${CHIP}
                        FBB_FOTA_MANIFEST=${_FOTA_MANIFEST}
                        ${Python3_EXECUTABLE} ${_FOTA_SCRIPT} ${PKG_TARGET_NAME} ${UPG_PKG}
                WORKING_DIRECTORY ${ROOT_DIR}
                DEPENDS ${TARGET_NAME} GENERAT_BIN ${_FOTA_SCRIPT}
                BYPRODUCTS ${OUTPUT_ROOT}/${CHIP}/upgrade
                VERBATIM
            )
            add_custom_target(package-fota DEPENDS ${_FOTA_MANIFEST})
        endif()
    endif()

    set(_SDK_PACKAGE_DEPENDS build-contract ${TARGET_NAME})
    if(TARGET package-fwpkg)
        list(APPEND _SDK_PACKAGE_DEPENDS package-fwpkg)
    endif()
    if(TARGET package-fota)
        list(APPEND _SDK_PACKAGE_DEPENDS package-fota)
    endif()
    if(TARGET HSO_DB)
        list(APPEND _SDK_PACKAGE_DEPENDS HSO_DB)
    endif()
    if(TARGET BUILD_ROM_CALLBACK)
        list(APPEND _SDK_PACKAGE_DEPENDS BUILD_ROM_CALLBACK)
    endif()

    add_custom_target(sdk-package DEPENDS ${_SDK_PACKAGE_DEPENDS})

    add_custom_target(postbuild-hso-db DEPENDS HSO_DB)

    if(TARGET BUILD_ROM_CALLBACK)
        add_custom_target(postbuild-rom-callback DEPENDS BUILD_ROM_CALLBACK)
    else()
        add_custom_target(postbuild-rom-callback
            COMMAND ${CMAKE_COMMAND} -E echo "BUILD_ROM_CALLBACK target is not enabled for ${FBB_TARGET}"
            VERBATIM
        )
    endif()

    add_custom_target(package-all)
    if(TARGET package-fwpkg)
        add_dependencies(package-all package-fwpkg)
    endif()
    if(TARGET package-fota)
        add_dependencies(package-all package-fota)
    endif()
    if(TARGET sdk-package)
        add_dependencies(package-all sdk-package)
    endif()
endif()

add_subdirectory_if_exist(application)
add_subdirectory_if_exist(bt)
add_subdirectory_if_exist(bootloader)
add_subdirectory_if_exist(kernel)
add_subdirectory_if_exist(drivers)
add_subdirectory_if_exist(middleware)
add_subdirectory_if_exist(open_source)
add_subdirectory_if_exist(protocol)
add_subdirectory_if_exist(test)
add_subdirectory_if_exist(include)
add_subdirectory_if_exist(vendor)

include("${CMAKE_DIR}/open_source.cmake")
include("${CMAKE_DIR}/build_linker.cmake")

if (NOT DEFINED ROM_COMPONENT)
set(GENERAT_BIN_OUT ${PROJECT_BINARY_DIR}/${BIN_NAME}.bin)
add_custom_command(
    OUTPUT ${GENERAT_BIN_OUT}
    COMMAND ${CMAKE_OBJCOPY} --gap-fill 0xFF -O binary -R .fls_loader_ram -R .logstr -R .ARM -R .ARM ${BIN_NAME}.elf ${BIN_NAME}.bin
    COMMENT "post_build:gen bin file"
    WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
    DEPENDS ${TARGET_NAME}
    VERBATIM
)
add_custom_target(GENERAT_BIN ALL
    DEPENDS ${GENERAT_BIN_OUT}
)
else()
set(GENERAT_BIN_RAM_OUT ${PROJECT_BINARY_DIR}/${TARGET_NAME}.bin)
set(GENERAT_BIN_ROM_OUT ${PROJECT_BINARY_DIR}/${TARGET_NAME}_rom.bin)
add_custom_command(
    OUTPUT ${GENERAT_BIN_RAM_OUT} ${GENERAT_BIN_ROM_OUT}
    COMMAND ${CMAKE_OBJCOPY} --gap-fill 0xFF -O binary -R .logstr -R .ARM.exidx -R .ARM.extab -R .*_romtext ${TARGET_NAME}.elf ${TARGET_NAME}.bin
    COMMAND ${CMAKE_OBJCOPY} --gap-fill 0xFF -O binary -j .*_romtext ${TARGET_NAME}.elf ${TARGET_NAME}_rom.bin
    COMMENT "post_build:gen rom and ram bin file"
    WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
    DEPENDS ${TARGET_NAME}
    VERBATIM
)
add_custom_target(GENERAT_BIN ALL
    DEPENDS ${GENERAT_BIN_RAM_OUT} ${GENERAT_BIN_ROM_OUT}
)
endif()

if(DEFINED CONFIG_SFC_SUPPORT_RWE_INDEPENDENT)
set(GENERAT_FLASH_DRIVER_BIN_OUT ${PROJECT_BINARY_DIR}/BOOTLOADERFlsDrv.signed.s19)
add_custom_command(
    OUTPUT ${GENERAT_FLASH_DRIVER_BIN_OUT}
    COMMAND ${CMAKE_OBJCOPY} -O srec --srec-len=0x20 --srec-forceS3 -S -j .fls_loader_ram ${BIN_NAME}.elf BOOTLOADERFlsDrv.signed.s19
    COMMENT "post_build:gen flash driver bin file"
    WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
    DEPENDS ${TARGET_NAME}
    VERBATIM
)
add_custom_target(GENERAT_FLASH_DRIVER_BIN ALL
    DEPENDS ${GENERAT_FLASH_DRIVER_BIN_OUT}
)
endif()

include("${CMAKE_DIR}/build_ssb.cmake")
include("${CMAKE_DIR}/build_elf_info.cmake")
include("${CMAKE_DIR}/build_sign.cmake")
include("${CMAKE_DIR}/build_nv_bin.cmake")
include("${CMAKE_DIR}/build_partition_bin.cmake")
include("${CMAKE_DIR}/build_boot_bin_cp.cmake")

create_hso_db()
generate_project_file()
