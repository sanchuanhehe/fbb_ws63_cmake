#===============================================================================
# @brief    cmake file
# Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2023-2023. All rights reserved.
#===============================================================================

if(NOT "${FLASHBOOT_CFG}" STREQUAL "")
set(COPY_FLASHBOOT_BIN_A ${ROOT_DIR}/interim_binary/${CHIP}/bin/boot_bin/flashboot_sign_a.bin)
set(COPY_FLASHBOOT_BIN_B ${ROOT_DIR}/interim_binary/${CHIP}/bin/boot_bin/flashboot_sign_b.bin)
add_custom_command(
    OUTPUT ${COPY_FLASHBOOT_BIN_A} ${COPY_FLASHBOOT_BIN_B}
    COMMAND ${CP} ${ROOT_DIR}/interim_binary/${CHIP}/bin/boot_bin/${FLASHBOOT_CFG}/flashboot_sign_a.bin ${COPY_FLASHBOOT_BIN_A}
    COMMAND ${CP} ${ROOT_DIR}/interim_binary/${CHIP}/bin/boot_bin/${FLASHBOOT_CFG}/flashboot_sign_b.bin ${COPY_FLASHBOOT_BIN_B}
    COMMENT "copy bin file"
    WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
    DEPENDS GENERAT_SIGNBIN
)
add_custom_target(COPY_FLASHBOOT_BIN ALL
    DEPENDS ${COPY_FLASHBOOT_BIN_A} ${COPY_FLASHBOOT_BIN_B}
)
endif()

if(NOT "${LOADERBOOT_CFG}" STREQUAL "")
set(COPY_LOADERBOOT_BIN_OUT ${ROOT_DIR}/interim_binary/${CHIP}/bin/boot_bin/loaderboot_sign.bin)
add_custom_command(
    OUTPUT ${COPY_LOADERBOOT_BIN_OUT}
    COMMAND ${CP} ${ROOT_DIR}/interim_binary/${CHIP}/bin/boot_bin/${LOADERBOOT_CFG}/loaderboot_sign.bin ${COPY_LOADERBOOT_BIN_OUT}
    COMMENT "copy bin file"
    WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
    DEPENDS GENERAT_SIGNBIN
)
add_custom_target(COPY_LOADERBOOT_BIN ALL
    DEPENDS ${COPY_LOADERBOOT_BIN_OUT}
)
endif()