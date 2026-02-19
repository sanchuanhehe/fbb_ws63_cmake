#===============================================================================
# @brief    cmake file
# Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2022-2022. All rights reserved.
#===============================================================================

if(DEFINED APPLICATION)
if(${APPLICATION} STREQUAL "ssb")
set(ADD_SHA_TO_SSB_OUTPUT ${PROJECT_BINARY_DIR}/${TARGET_NAME}_sha.bin)
add_custom_command(
    OUTPUT ${ADD_SHA_TO_SSB_OUTPUT}
    COMMAND ${Python3_EXECUTABLE} ${BUILD_UTILS} add_len_and_sha256_info_to_ssb ${TARGET_NAME}.bin ${CHIP} ${ADD_SHA_TO_SSB_OUTPUT}
    COMMAND ${CMAKE_COMMAND} -E copy_if_different ${ADD_SHA_TO_SSB_OUTPUT} ${TARGET_NAME}.bin
    COMMENT "add ssb length and sha256 info into ssb.bin"
    WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
    DEPENDS GENERAT_BIN
)
add_custom_target(ADD_SHA_TO_SSB ALL
    DEPENDS ${ADD_SHA_TO_SSB_OUTPUT}
)
endif()
endif()
