#===============================================================================
# @brief    cmake file
# Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2022-2023. All rights reserved.
#===============================================================================

if (${TARGET_NAME} STREQUAL "flashboot")
if (EXISTS ${ROOT_DIR}/build/config/target_config/${CHIP}/sign_config/${BUILD_TARGET_NAME}.cfg)
    set(SIGN_CONFIG_FILE ${ROOT_DIR}/build/config/target_config/${CHIP}/sign_config/${BUILD_TARGET_NAME}.cfg)
    if (NOT ${SEC_BOOT} STREQUAL "")
        set(CONCAT_BIN_OUTPUT ${PROJECT_BINARY_DIR}/flashboot_concat.bin)
        add_custom_command(
            OUTPUT ${CONCAT_BIN_OUTPUT}
            COMMAND ${Python3_EXECUTABLE} ${CONCAT_TOOL} ${ROOT_DIR}/interim_binary/${CHIP}/bin/boot_bin/${SEC_BOOT}/sec_boot.bin ${PROJECT_BINARY_DIR}/flashboot.bin ${SEC_BOOT_SIZE} ${CONCAT_BIN_OUTPUT}
            COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CONCAT_BIN_OUTPUT} ${PROJECT_BINARY_DIR}/flashboot.bin
            COMMENT "concat bin"
            WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
            DEPENDS GENERAT_BIN
            VERBATIM
        )
        add_custom_target(CONCAT_BIN ALL
            DEPENDS ${CONCAT_BIN_OUTPUT}
        )
    endif()
    set(FLASHBOOT_SIGN_A ${PROJECT_BINARY_DIR}/flashboot_sign_a.bin)
    set(FLASHBOOT_SIGN_B ${PROJECT_BINARY_DIR}/flashboot_sign_b.bin)
    add_custom_command(
        OUTPUT ${FLASHBOOT_SIGN_A} ${FLASHBOOT_SIGN_B}
        COMMAND ${SIGN_TOOL} 0 ${SIGN_CONFIG_FILE}
        COMMAND ${CP} ${FLASHBOOT_SIGN_A} ${FLASHBOOT_SIGN_B}
        COMMENT "sign file:gen boot sign file"
        WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
        DEPENDS GENERAT_BIN ${CONCAT_BIN_OUTPUT}
        VERBATIM
    )
    add_custom_target(GENERAT_SIGNBIN ALL
        DEPENDS ${FLASHBOOT_SIGN_A} ${FLASHBOOT_SIGN_B}
    )
    if (NOT ${SEC_BOOT} STREQUAL "")
        add_dependencies(GENERAT_SIGNBIN CONCAT_BIN)
    endif()
    if (${UPDATE_BIN})
        string(REPLACE "_" "-" TARGET_DIR ${BUILD_TARGET_NAME})
        if (NOT EXISTS ${ROOT_DIR}/interim_binary/${CHIP}/bin/boot_bin)
            file(MAKE_DIRECTORY ${ROOT_DIR}/interim_binary/${CHIP}/bin/boot_bin)
        endif()
        if (NOT EXISTS ${ROOT_DIR}/interim_binary/${CHIP}/bin/boot_bin/${TARGET_DIR})
            file(MAKE_DIRECTORY ${ROOT_DIR}/interim_binary/${CHIP}/bin/boot_bin/${TARGET_DIR})
        endif()
        set(COPY_FLASHBOOT_SIGN_A ${ROOT_DIR}/interim_binary/${CHIP}/bin/boot_bin/${TARGET_DIR}/flashboot_sign_a.bin)
        set(COPY_FLASHBOOT_SIGN_B ${ROOT_DIR}/interim_binary/${CHIP}/bin/boot_bin/${TARGET_DIR}/flashboot_sign_b.bin)
        add_custom_command(
            OUTPUT ${COPY_FLASHBOOT_SIGN_A} ${COPY_FLASHBOOT_SIGN_B}
            COMMAND ${CP} ${ROOT_DIR}/output/${CHIP}/acore/${TARGET_DIR}/flashboot_sign_a.bin ${COPY_FLASHBOOT_SIGN_A}
            COMMAND ${CP} ${ROOT_DIR}/output/${CHIP}/acore/${TARGET_DIR}/flashboot_sign_a.bin ${COPY_FLASHBOOT_SIGN_B}
            COMMENT "copy bin file"
            WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
            DEPENDS GENERAT_SIGNBIN
            VERBATIM
        )
        add_custom_target(COPY_SIGNBIN ALL
            DEPENDS ${COPY_FLASHBOOT_SIGN_A} ${COPY_FLASHBOOT_SIGN_B}
        )
    endif()
endif()
elseif (${TARGET_NAME} STREQUAL "loaderboot")
if (EXISTS ${ROOT_DIR}/build/config/target_config/${CHIP}/sign_config/${BUILD_TARGET_NAME}.cfg)
    set(SIGN_CONFIG_FILE ${ROOT_DIR}/build/config/target_config/${CHIP}/sign_config/${BUILD_TARGET_NAME}.cfg)
    set(LOADERBOOT_SIGN_BIN ${PROJECT_BINARY_DIR}/loaderboot_sign.bin)
    add_custom_command(
        OUTPUT ${LOADERBOOT_SIGN_BIN}
        COMMAND ${SIGN_TOOL} 0 ${SIGN_CONFIG_FILE}
        COMMENT "sign file:gen boot sign file"
        WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
        DEPENDS GENERAT_BIN
        VERBATIM
    )
    add_custom_target(GENERAT_SIGNBIN ALL
        DEPENDS ${LOADERBOOT_SIGN_BIN}
    )
    if (${UPDATE_BIN})
        string(REPLACE "_" "-" TARGET_DIR ${BUILD_TARGET_NAME})
        if (NOT EXISTS ${ROOT_DIR}/interim_binary/${CHIP}/bin/boot_bin)
            file(MAKE_DIRECTORY ${ROOT_DIR}/interim_binary/${CHIP}/bin/boot_bin)
        endif()
        if (NOT EXISTS ${ROOT_DIR}/interim_binary/${CHIP}/bin/boot_bin/${TARGET_DIR})
            file(MAKE_DIRECTORY ${ROOT_DIR}/interim_binary/${CHIP}/bin/boot_bin/${TARGET_DIR})
        endif()
        set(COPY_LOADERBOOT_SIGN ${ROOT_DIR}/interim_binary/${CHIP}/bin/boot_bin/${TARGET_DIR}/loaderboot_sign.bin)
        add_custom_command(
            OUTPUT ${COPY_LOADERBOOT_SIGN}
            COMMAND ${CP} ${ROOT_DIR}/output/${CHIP}/acore/${TARGET_DIR}/loaderboot_sign.bin ${COPY_LOADERBOOT_SIGN}
            COMMENT "copy bin file"
            WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
            DEPENDS GENERAT_SIGNBIN
            VERBATIM
        )
        add_custom_target(COPY_SIGNBIN ALL
            DEPENDS ${COPY_LOADERBOOT_SIGN}
        )
    endif()
endif()
elseif (${TARGET_NAME} MATCHES "application*" OR ${TARGET_NAME} STREQUAL "ate_debug" OR ${TARGET_NAME} STREQUAL "ate" OR
        ${TARGET_NAME} MATCHES "protocol*" )
if (EXISTS ${ROOT_DIR}/build/config/target_config/${CHIP}/sign_config/${BUILD_TARGET_NAME}.cfg)
set(SIGN_CONFIG_FILE ${ROOT_DIR}/build/config/target_config/${CHIP}/sign_config/${BUILD_TARGET_NAME}.cfg)
set(GENERAT_SIGNBIN_OUTPUT ${PROJECT_BINARY_DIR}/${BIN_NAME}_sign.bin)
add_custom_command(
    OUTPUT ${GENERAT_SIGNBIN_OUTPUT}
    COMMAND ${SIGN_TOOL} 0 ${SIGN_CONFIG_FILE}
    COMMENT "sign file:gen boot sign file"
    WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
    DEPENDS GENERAT_BIN
    VERBATIM
)
add_custom_target(GENERAT_SIGNBIN ALL
    DEPENDS ${GENERAT_SIGNBIN_OUTPUT}
)
endif()
elseif (${TARGET_NAME} MATCHES "control_ws53*")
if (EXISTS ${ROOT_DIR}/build/config/target_config/${CHIP}/sign_config/${BUILD_TARGET_NAME}.cfg)
set(SIGN_CONFIG_FILE ${ROOT_DIR}/build/config/target_config/${CHIP}/sign_config/${BUILD_TARGET_NAME}.cfg)
set(GENERAT_SIGNBIN_OUTPUT ${PROJECT_BINARY_DIR}/${BIN_NAME}_sign.bin)
add_custom_command(
    OUTPUT ${GENERAT_SIGNBIN_OUTPUT}
    COMMAND ${SIGN_TOOL} 0 ${SIGN_CONFIG_FILE}
    COMMENT "sign file:gen boot sign file"
    WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
    DEPENDS GENERAT_BIN
    VERBATIM
)
add_custom_target(GENERAT_SIGNBIN ALL
    DEPENDS ${GENERAT_SIGNBIN_OUTPUT}
)
endif()
endif()
if (${CHIP} STREQUAL "ws63" AND NOT (${TARGET_NAME} STREQUAL "flashboot" OR ${TARGET_NAME} STREQUAL "loaderboot"))
set(WS63_SIGN_MANIFEST ${OUTPUT_ROOT}/${CHIP}/${CORE}/sign_manifest/${TARGET_NAME}.json)
add_custom_command(
    OUTPUT ${WS63_SIGN_MANIFEST}
    COMMAND ${CMAKE_COMMAND} -E env
        FBB_SIGN_INPUT_MANIFEST=${FBB_CONTRACT_FILE}
        FBB_OUTPUT_ROOT=${OUTPUT_ROOT}
        FBB_CHIP=${CHIP}
        FBB_CORE=${CORE}
        FBB_SIGN_MANIFEST=${WS63_SIGN_MANIFEST}
        ${Python3_EXECUTABLE} ${ROOT_DIR}/build/config/target_config/${CHIP}/sign_config/params_and_bin_sign.py ${TARGET_NAME}
    COMMENT "ws63 image sign"
    WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
    DEPENDS GENERAT_BIN ${GENERAT_ROM_PATCH} ${FBB_CONTRACT_FILE} ${ROOT_DIR}/build/config/target_config/${CHIP}/sign_config/params_and_bin_sign.py
    VERBATIM
)
add_custom_target(WS63_GENERAT_SIGNBIN ALL
    DEPENDS ${WS63_SIGN_MANIFEST}
)

if(TARGET GENERAT_ROM_PATCH)
    add_dependencies(WS63_GENERAT_SIGNBIN GENERAT_ROM_PATCH)
endif()
endif()

if (${CHIP} STREQUAL "ws53")
set(WS53_SIGN_MANIFEST ${PROJECT_BINARY_DIR}/sign_manifest/ws53_sign.manifest)
add_custom_command(
    OUTPUT ${WS53_SIGN_MANIFEST}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${PROJECT_BINARY_DIR}/sign_manifest
    COMMAND sh ${ROOT_DIR}/build/config/target_config/${CHIP}/sign_config/params_and_bin_sign.sh
    COMMAND ${CMAKE_COMMAND} -E touch ${WS53_SIGN_MANIFEST}
    COMMENT "ws53 image sign"
    WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
    DEPENDS GENERAT_BIN ${GENERAT_ROM_PATCH}
    VERBATIM
)
add_custom_target(WS53_GENERAT_SIGNBIN ALL
    DEPENDS ${WS53_SIGN_MANIFEST}
)

if(TARGET GENERAT_ROM_PATCH)
    add_dependencies(WS53_GENERAT_SIGNBIN GENERAT_ROM_PATCH)
endif()
endif()

if(TARGET GENERAT_ROM_PATCH AND TARGET GENERAT_SIGNBIN)
    add_dependencies(GENERAT_SIGNBIN GENERAT_ROM_PATCH)
endif()

if (${TARGET_NAME} STREQUAL "sec_boot")
    if (${UPDATE_BIN})
        string(REPLACE "_" "-" TARGET_DIR ${BUILD_TARGET_NAME})
        if (NOT EXISTS ${ROOT_DIR}/interim_binary/${CHIP}/bin/boot_bin)
            file(MAKE_DIRECTORY ${ROOT_DIR}/interim_binary/${CHIP}/bin/boot_bin)
        endif()
        if (NOT EXISTS ${ROOT_DIR}/interim_binary/${CHIP}/bin/boot_bin/${TARGET_DIR})
            file(MAKE_DIRECTORY ${ROOT_DIR}/interim_binary/${CHIP}/bin/boot_bin/${TARGET_DIR})
        endif()
        set(COPY_SEC_BOOT_BIN ${ROOT_DIR}/interim_binary/${CHIP}/bin/boot_bin/${TARGET_DIR}/sec_boot.bin)
        add_custom_command(
            OUTPUT ${COPY_SEC_BOOT_BIN}
            COMMAND ${CP} ${ROOT_DIR}/output/${CHIP}/acore/${TARGET_DIR}/sec_boot.bin ${COPY_SEC_BOOT_BIN}
            COMMENT "copy bin file"
            WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
            DEPENDS GENERAT_BIN
            VERBATIM
        )
        add_custom_target(COPY_SEC_BOOTBIN ALL
            DEPENDS ${COPY_SEC_BOOT_BIN}
        )
    endif()
endif()

if(${GEN_SEC_BIN} AND ${GEN_SEC_BIN} STREQUAL "True")
    if(${CORE} STREQUAL "acore")
        if (TARGET GENERAT_SIGNBIN)
            set(GENERAT_SEC_IMAGE_OUTPUT ${PROJECT_BINARY_DIR}/${BIN_NAME}_sign.sec.bin)
            add_custom_command(
                OUTPUT ${GENERAT_SEC_IMAGE_OUTPUT}
                COMMAND ${CMAKE_COMMAND} -E copy_if_different ${PROJECT_BINARY_DIR}/${BIN_NAME}_sign.bin ${GENERAT_SEC_IMAGE_OUTPUT}
                COMMAND ${CMAKE_OBJCOPY} --enable_sec ${GENERAT_SEC_IMAGE_OUTPUT}
                WORKING_DIRECTORY ${COMPILER_ROOT}/bin
                DEPENDS GENERAT_SIGNBIN
                VERBATIM
            )
            add_custom_target(GENERAT_SEC_IMAGE ALL
                DEPENDS ${GENERAT_SEC_IMAGE_OUTPUT}
            )
        else()
            set(GENERAT_SEC_IMAGE_OUTPUT ${PROJECT_BINARY_DIR}/${BIN_NAME}.sec.bin)
            add_custom_command(
                OUTPUT ${GENERAT_SEC_IMAGE_OUTPUT}
                COMMAND ${CMAKE_COMMAND} -E copy_if_different ${PROJECT_BINARY_DIR}/${BIN_NAME}.bin ${GENERAT_SEC_IMAGE_OUTPUT}
                COMMAND ${CMAKE_OBJCOPY} --enable_sec ${GENERAT_SEC_IMAGE_OUTPUT}
                WORKING_DIRECTORY ${COMPILER_ROOT}/bin
                DEPENDS GENERAT_BIN
                VERBATIM
            )
            add_custom_target(GENERAT_SEC_IMAGE ALL
                DEPENDS ${GENERAT_SEC_IMAGE_OUTPUT}
            )
        endif()
    elseif(${CORE} STREQUAL "bt_core")
        set(GENERAT_SEC_IMAGE_OUTPUT ${PROJECT_BINARY_DIR}/${BIN_NAME}.sec.bin)
        add_custom_command(
            OUTPUT ${GENERAT_SEC_IMAGE_OUTPUT}
            COMMAND ${CMAKE_COMMAND} -E copy_if_different ${PROJECT_BINARY_DIR}/${BIN_NAME}.bin ${GENERAT_SEC_IMAGE_OUTPUT}
            COMMAND ${SEC_OBJCPY_TOOL} --enable_sec ${GENERAT_SEC_IMAGE_OUTPUT}
            WORKING_DIRECTORY ${SEC_TOOL_DIR}
            DEPENDS GENERAT_ROM_PATCH
            VERBATIM
        )
        add_custom_target(GENERAT_SEC_IMAGE ALL
            DEPENDS ${GENERAT_SEC_IMAGE_OUTPUT}
        )
    endif()
endif()

