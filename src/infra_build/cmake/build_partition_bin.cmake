#===============================================================================
# @brief    cmake file
# Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2023-2023. All rights reserved.
#===============================================================================

if(NOT "${SECTOR_CFG}" STREQUAL "")
    SET(SECTOR_JSON ${ROOT_DIR}/infra_build/config/target_config/${CHIP}/flash_sector_config/${SECTOR_CFG}.json)
    SET(SECTOR_BIN_PATH ${ROOT_DIR}/interim_binary/${CHIP}/bin/partition/${PKG_TARGET_NAME})
    if (NOT EXISTS ${SECTOR_BIN_PATH})
        file(MAKE_DIRECTORY ${SECTOR_BIN_PATH})
    endif()
    set(PARTITION_BIN_OUT ${PROJECT_BINARY_DIR}/partition.bin)
    add_custom_command(
        OUTPUT ${PARTITION_BIN_OUT}
        COMMAND ${Python3_EXECUTABLE} ${ROOT_DIR}/infra_build/script/param_packet.py ${SECTOR_JSON} ${SECTOR_BIN_PATH}/partition.bin
        COMMAND ${CP} ${SECTOR_BIN_PATH}/partition.bin ${PARTITION_BIN_OUT}
        COMMENT "update partition bin"
        WORKING_DIRECTORY ${ROOT_DIR}
        DEPENDS GENERAT_BIN
    )
    add_custom_target(GENERAT_PARTITION ALL
        DEPENDS ${PARTITION_BIN_OUT}
    )
endif()
