#===============================================================================
# @brief    cmake global variable init
# Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2022-2022. All rights reserved.
#===============================================================================

set_property(GLOBAL PROPERTY ALL_PUBLIC_HEADER "")
set_property(GLOBAL PROPERTY ALL_HEADER "")
set_property(GLOBAL PROPERTY ALL_PUBLIC_DEFINES ${DEFINES})
set_property(GLOBAL PROPERTY ALL_PUBLIC_CCFLAGS "${CCFLAGS}")
set_property(GLOBAL PROPERTY ALL_SOURCES "")
set_property(GLOBAL PROPERTY LOS_LIB "")
set_property(GLOBAL PROPERTY LINKER_DIR "")
set_property(GLOBAL PROPERTY SDK_PROJECT_FILE_DIR "")
set_property(GLOBAL PROPERTY LOG_DEF_LIST "")
set_property(GLOBAL PROPERTY WSTP_HEADER_LIST "")
set_property(GLOBAL PROPERTY PLAT_SRC_LIST "")
set_property(GLOBAL PROPERTY WSTP_SRC_LIST "")
set_property(GLOBAL PROPERTY TEST_HAED_LIST "")
set_property(GLOBAL PROPERTY BTH_SDK_LIST "")

# Backward-compatible variable mirrors
set(ALL_PUBLIC_HEADER "")
set(ALL_HEADER "")
set(ALL_PUBLIC_DEFINES ${DEFINES})
set(ALL_PUBLIC_CCFLAGS "${CCFLAGS}")
set(ALL_SOURCES "")
set(LOS_LIB "")
set(LINKER_DIR "")
set(SDK_PROJECT_FILE_DIR "")
set(LOG_DEF_LIST "")
set(WSTP_HEADER_LIST "")
set(PLAT_SRC_LIST "")
set(WSTP_SRC_LIST "")
set(TEST_HAED_LIST "")
set(BTH_SDK_LIST "")