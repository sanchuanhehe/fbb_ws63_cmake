#===============================================================================
# @brief    cmake file
# Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2022-2022. All rights reserved.
#===============================================================================

if(DEFINED APPLICATION)
if(${APPLICATION} STREQUAL "ssb")
set(ADD_SHA_TO_SSB_STAMP ${PROJECT_BINARY_DIR}/.add_sha_to_ssb.stamp)
add_custom_command(
    OUTPUT ${ADD_SHA_TO_SSB_STAMP}
    COMMAND ${Python3_EXECUTABLE} ${BUILD_UTILS} add_len_and_sha256_info_to_ssb ${TARGET_NAME}.bin ${CHIP}
    COMMAND ${CMAKE_COMMAND} -E touch ${ADD_SHA_TO_SSB_STAMP}
    COMMENT "add ssb length and sha256 info into ssb.bin"
    WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
    DEPENDS GENERAT_BIN
)
add_custom_target(ADD_SHA_TO_SSB ALL
    DEPENDS ${ADD_SHA_TO_SSB_STAMP}
)
endif()
endif()
