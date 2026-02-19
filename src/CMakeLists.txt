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
    set(_KCONFIG_STAMP "${PROJECT_BINARY_DIR}/kconfig_header.stamp")
    add_custom_command(
        OUTPUT ${_KCONFIG_STAMP}
        COMMAND ${Python3_EXECUTABLE} ${ROOT_DIR}/build/script/usr_config.py --command savemenuconfig --chip ${CHIP} --core ${CORE} --target ${PKG_TARGET_NAME} --output ${PROJECT_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E touch ${_KCONFIG_STAMP}
        WORKING_DIRECTORY ${ROOT_DIR}
        DEPENDS ${ROOT_DIR}/build/script/usr_config.py
        BYPRODUCTS ${_KCONFIG_HEADER}
        VERBATIM
    )

    add_custom_target(kconfig-menuconfig
        COMMAND ${Python3_EXECUTABLE} ${ROOT_DIR}/build/script/usr_config.py --command menuconfig --chip ${CHIP} --core ${CORE} --target ${PKG_TARGET_NAME} --output ${PROJECT_BINARY_DIR}
        WORKING_DIRECTORY ${ROOT_DIR}
        USES_TERMINAL
    )

    add_custom_target(kconfig-defconfig
        COMMAND ${Python3_EXECUTABLE} ${ROOT_DIR}/build/script/usr_config.py --command defconfig --chip ${CHIP} --core ${CORE} --target ${PKG_TARGET_NAME} --output ${PROJECT_BINARY_DIR}
        WORKING_DIRECTORY ${ROOT_DIR}
        USES_TERMINAL
    )

    add_custom_target(kconfig-reload
        COMMAND ${Python3_EXECUTABLE} ${ROOT_DIR}/build/script/usr_config.py --command reloadconfig --chip ${CHIP} --core ${CORE} --target ${PKG_TARGET_NAME} --output ${PROJECT_BINARY_DIR}
        WORKING_DIRECTORY ${ROOT_DIR}
        USES_TERMINAL
    )

    add_custom_target(kconfig-header
        DEPENDS ${_KCONFIG_STAMP}
    )

    if(DEFINED PACKET AND PACKET)
        set(_FWPKG_STAMP "${PROJECT_BINARY_DIR}/fbb_package_fwpkg.stamp")
        add_custom_command(
            OUTPUT ${_FWPKG_STAMP}
            COMMAND ${Python3_EXECUTABLE} ${ROOT_DIR}/tools/pkg/packet.py ${CHIP} ${PKG_TARGET_NAME} "${FBB_EXTRA_DEFINES}"
            COMMAND ${CMAKE_COMMAND} -E touch ${_FWPKG_STAMP}
            WORKING_DIRECTORY ${ROOT_DIR}
            DEPENDS ${TARGET_NAME}
            BYPRODUCTS ${OUTPUT_ROOT}/${CHIP}/fwpkg
            VERBATIM
        )
        add_custom_target(package-fwpkg DEPENDS ${_FWPKG_STAMP})
    endif()

    if(DEFINED UPG_PKG AND NOT "${UPG_PKG}" STREQUAL "")
        set(_FOTA_SCRIPT ${ROOT_DIR}/build/config/target_config/${CHIP}/build_${CHIP}_update.py)
        if(EXISTS ${_FOTA_SCRIPT})
            set(_FOTA_STAMP "${PROJECT_BINARY_DIR}/fbb_package_fota.stamp")
            add_custom_command(
                OUTPUT ${_FOTA_STAMP}
                COMMAND ${Python3_EXECUTABLE} ${_FOTA_SCRIPT} ${PKG_TARGET_NAME} ${UPG_PKG}
                COMMAND ${CMAKE_COMMAND} -E touch ${_FOTA_STAMP}
                WORKING_DIRECTORY ${ROOT_DIR}
                DEPENDS ${TARGET_NAME}
                BYPRODUCTS ${OUTPUT_ROOT}/${CHIP}/fwpkg
                VERBATIM
            )
            add_custom_target(package-fota DEPENDS ${_FOTA_STAMP})
        endif()
    endif()

    set(_SDK_STAMP "${PROJECT_BINARY_DIR}/fbb_package_sdk.stamp")
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

    add_custom_command(
        OUTPUT ${_SDK_STAMP}
        COMMAND ${CMAKE_COMMAND} -E touch ${_SDK_STAMP}
        DEPENDS ${_SDK_PACKAGE_DEPENDS}
        VERBATIM
    )
    add_custom_target(sdk-package DEPENDS ${_SDK_STAMP})

    add_custom_target(postbuild-hso-db DEPENDS HSO_DB)

    if(TARGET BUILD_ROM_CALLBACK)
        add_custom_target(postbuild-rom-callback DEPENDS BUILD_ROM_CALLBACK)
    else()
        set(_ROM_CB_FALLBACK_STAMP "${PROJECT_BINARY_DIR}/postbuild_rom_callback_disabled.stamp")
        add_custom_command(
            OUTPUT ${_ROM_CB_FALLBACK_STAMP}
            COMMAND ${CMAKE_COMMAND} -E echo "BUILD_ROM_CALLBACK target is not enabled for ${FBB_TARGET}"
            COMMAND ${CMAKE_COMMAND} -E touch ${_ROM_CB_FALLBACK_STAMP}
            VERBATIM
        )
        add_custom_target(postbuild-rom-callback
            DEPENDS ${_ROM_CB_FALLBACK_STAMP}
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
