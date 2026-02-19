#===============================================================================
# @brief    cmake file
# Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2022-2022. All rights reserved.
#===============================================================================
set(MODULE_NAME "bt")

function(bgtp_get_property_or_var out_var property_name fallback_var)
    get_property(_value GLOBAL PROPERTY ${property_name})
    if((NOT DEFINED _value OR "${_value}" STREQUAL "") AND DEFINED ${fallback_var})
        set(_value "${${fallback_var}}")
    endif()
    set(${out_var} "${_value}" PARENT_SCOPE)
endfunction()

macro(bgtp_reset_shared_list list_name)
    set_property(GLOBAL PROPERTY ${list_name} "")
    set(${list_name} "")
endmacro()

macro(bgtp_set_shared_list list_name list_value)
    set_property(GLOBAL PROPERTY ${list_name} "${list_value}")
    set(${list_name} "${list_value}")
endmacro()

# bgtp与bgtp_rom组件公共部分
bgtp_reset_shared_list(BTC_RAM_LIST)
bgtp_reset_shared_list(BTC_ROM_LIST)
bgtp_reset_shared_list(BTC_ROM_DATA_LIST)
bgtp_reset_shared_list(BTC_HEADER_LIST)
set(AUTO_DEF_FILE_ID TRUE)

if(DEFINED ROM_COMPONENT)
    set(BT_ROM_VERSION true)
else()
    set(BT_ROM_VERSION false)
endif()

if("DEVICE_ONLY" IN_LIST DEFINES)
    set(BGTP_DEVICE_ONLY true)
else()
    set(BGTP_DEVICE_ONLY false)
endif()

if(BGTP_DEVICE_ONLY)
    set(BT_ONETRACK false)
else()
    set(BT_ONETRACK true)
endif()

MESSAGE("BGTP_PROJECT=" ${BGTP_PROJECT})
MESSAGE("BGTP_ROM_VERSION=" ${BT_ROM_VERSION})
MESSAGE("BGTP_DEVICE_ONLY=" ${BGTP_DEVICE_ONLY})

add_subdirectory_if_exist(chip)

bgtp_get_property_or_var(BTC_RAM_LIST_RESOLVED BTC_RAM_LIST BTC_RAM_LIST)
bgtp_get_property_or_var(BTC_ROM_LIST_RESOLVED BTC_ROM_LIST BTC_ROM_LIST)
bgtp_get_property_or_var(BTC_ROM_DATA_LIST_RESOLVED BTC_ROM_DATA_LIST BTC_ROM_DATA_LIST)
bgtp_get_property_or_var(BTC_HEADER_LIST_RESOLVED BTC_HEADER_LIST BTC_HEADER_LIST)

set(PRIVATE_DEFINES
)

set(PUBLIC_DEFINES
    "BTC_SYS_PART=100"
)

set(COMPONENT_PUBLIC_CCFLAGS
)

set(COMPONENT_CCFLAGS
	-Wundef
)

set(WHOLE_LINK
    true
)

set(MAIN_COMPONENT
    false
)

# ram组件，编译BTC_RAM_LIST
set(COMPONENT_NAME "bgtp")

if("${BTC_RAM_LIST_RESOLVED}" STREQUAL "")
    bgtp_set_shared_list(BTC_RAM_LIST "__null__")
    set(BTC_RAM_LIST_RESOLVED "__null__")
endif()

set(SOURCES
    ${BTC_RAM_LIST_RESOLVED}
)

set(PUBLIC_HEADER
    ${BTC_HEADER_LIST_RESOLVED}
)

set(PRIVATE_HEADER
)

unset(CMAKE_ARCHIVE_OUTPUT_DIRECTORY)
if("UPDATE_BTC_STATIC_LIB" IN_LIST DEFINES)
    set(LIB_OUT_PATH ${BIN_DIR}/${CHIP}/libs/bluetooth/btc/${TARGET_COMMAND})
endif()
build_component()

# rom组件，编译BTC_ROM_LIST
set(COMPONENT_NAME "bgtp_rom")
set(SOURCES
    ${BTC_ROM_LIST_RESOLVED}
)

set(PUBLIC_HEADER
    ${BTC_HEADER_LIST_RESOLVED}
)

set(PRIVATE_HEADER
)

unset(CMAKE_ARCHIVE_OUTPUT_DIRECTORY)
if("UPDATE_BTC_STATIC_LIB" IN_LIST DEFINES)
    set(LIB_OUT_PATH ${BIN_DIR}/${CHIP}/libs/bluetooth/btc/${TARGET_COMMAND})
endif()
build_component()

if(DEFINED ROM_SYM_PATH)
set(COMPONENT_NAME "bgtp_rom_data")
if("${BTC_ROM_DATA_LIST_RESOLVED}" STREQUAL "")
    bgtp_set_shared_list(BTC_ROM_DATA_LIST "__null__")
    set(BTC_ROM_DATA_LIST_RESOLVED "__null__")
endif()

set(SOURCES
    ${BTC_ROM_DATA_LIST_RESOLVED}
)

unset(CMAKE_ARCHIVE_OUTPUT_DIRECTORY)
if("UPDATE_BTC_STATIC_LIB" IN_LIST DEFINES)
    set(LIB_OUT_PATH ${BIN_DIR}/${CHIP}/libs/bluetooth/btc/${TARGET_COMMAND})
endif()
build_component()
endif()
