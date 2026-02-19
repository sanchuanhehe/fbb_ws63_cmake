#===============================================================================
# @brief    cmake file
# Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd.. 2023. All rights reserved.
#===============================================================================
set(COMPONENT_NAME "bt_host")

function(bt_get_property_or_var out_var property_name fallback_var)
    get_property(_value GLOBAL PROPERTY ${property_name})
    if((NOT DEFINED _value OR "${_value}" STREQUAL "") AND DEFINED ${fallback_var})
        set(_value "${${fallback_var}}")
    endif()
    set(${out_var} "${_value}" PARENT_SCOPE)
endfunction()

macro(bt_reset_shared_list list_name)
    set_property(GLOBAL PROPERTY ${list_name} "")
    set(${list_name} "")
endmacro()

macro(bt_set_shared_list list_name list_value)
    set_property(GLOBAL PROPERTY ${list_name} "${list_value}")
    set(${list_name} "${list_value}")
endmacro()

bt_reset_shared_list(BTH_RAM_LIST)
bt_reset_shared_list(BTA_RAM_LIST)
bt_reset_shared_list(BTH_PUBLIC_HDR_LIST)
bt_reset_shared_list(BTH_PRIVATE_HDR_LIST)
bt_reset_shared_list(BTH_ROM_LIST)
bt_reset_shared_list(BTA_ROM_LIST)

if(DEFINED ROM_COMPONENT OR DEFINED ROM_SYM_PATH)
    set(BT_ROM_VERSION true)
else()
    set(BT_ROM_VERSION false)
endif()

add_subdirectory_if_exist(host)
add_subdirectory_if_exist(util)
if(BT_GLE_ONLY IN_LIST DEFINES)
    add_subdirectory_if_exist(ahi/ahi_b/ahi_vendor) # vendor_init方法
else()
    add_subdirectory_if_exist(ahi/ahi_b)
endif()

bt_get_property_or_var(BTH_RAM_LIST_RESOLVED BTH_RAM_LIST BTH_RAM_LIST)
bt_get_property_or_var(BTH_PUBLIC_HDR_LIST_RESOLVED BTH_PUBLIC_HDR_LIST BTH_PUBLIC_HDR_LIST)
bt_get_property_or_var(BTH_PRIVATE_HDR_LIST_RESOLVED BTH_PRIVATE_HDR_LIST BTH_PRIVATE_HDR_LIST)
bt_get_property_or_var(BTH_ROM_LIST_RESOLVED BTH_ROM_LIST BTH_ROM_LIST)

if("${BTH_RAM_LIST_RESOLVED}" STREQUAL "")
    if(DEFINED CONFIG_SLE_BLE_SUPPORT AND SUPPORT_MULTI_LIBS IN_LIST DEFINES)
        set(LIBS ${CMAKE_CURRENT_SOURCE_DIR}/${CHIP}-${CONFIG_SLE_BLE_SUPPORT}/lib${COMPONENT_NAME}.a)
    elseif(DEFINED CONFIG_SUPPORT_SLE_BLE_CENTRAL_DEFAULT)
        set(LIBS ${CMAKE_CURRENT_SOURCE_DIR}/${TARGET_COMMAND}/lib${COMPONENT_NAME}.a)
    else()
        bt_set_shared_list(BTH_RAM_LIST "__null__")
        set(BTH_RAM_LIST_RESOLVED "__null__")
    endif()
endif()
set(SOURCES
    ${BTH_RAM_LIST_RESOLVED}
)

if(BT_GLE_ONLY IN_LIST DEFINES)
set(PUBLIC_HEADER
    ${BTH_PUBLIC_HDR_LIST_RESOLVED}
    ${CMAKE_CURRENT_SOURCE_DIR}/ahi/ahi_b/ahi_vendor/inc
)

set(PRIVATE_HEADER
    ${BTH_PRIVATE_HDR_LIST_RESOLVED}
    ${CMAKE_CURRENT_SOURCE_DIR}/../bg_common/include/ipc
    ${CMAKE_CURRENT_SOURCE_DIR}/host/bs21/ram/sdk/include # 只要SDK头文件
)
else()
set(PUBLIC_HEADER
    ${BTH_PUBLIC_HDR_LIST_RESOLVED}
)

set(PRIVATE_HEADER
    ${BTH_PRIVATE_HDR_LIST_RESOLVED}
    ${CMAKE_CURRENT_SOURCE_DIR}/../bg_common/include/ipc
)
endif()

set(PRIVATE_DEFINES
)

set(PUBLIC_DEFINES
)

# use this when you want to add ccflags like -include xxx
set(COMPONENT_PUBLIC_CCFLAGS
)

set(COMPONENT_CCFLAGS
)

set(WHOLE_LINK
    true
)

set(MAIN_COMPONENT
    false
)

set(LIB_OUT_PATH ${BIN_DIR}/${CHIP}/libs/bluetooth/bth/${TARGET_COMMAND})

build_component()

set(COMPONENT_NAME "bt_host_rom")

if("${BTH_ROM_LIST_RESOLVED}" STREQUAL "")
    bt_set_shared_list(BTH_ROM_LIST "__null__")
    set(BTH_ROM_LIST_RESOLVED "__null__")
endif()

set(SOURCES
    ${BTH_ROM_LIST_RESOLVED}
)

set(PUBLIC_HEADER
    ${BTH_PUBLIC_HDR_LIST_RESOLVED}
)

set(PRIVATE_HEADER
    ${BTH_PRIVATE_HDR_LIST_RESOLVED}
    ${CMAKE_CURRENT_SOURCE_DIR}/../bg_common/include/ipc
)

set(PRIVATE_DEFINES
)

set(PUBLIC_DEFINES
)

# use this when you want to add ccflags like -include xxx
set(COMPONENT_PUBLIC_CCFLAGS
)

set(COMPONENT_CCFLAGS
)

set(WHOLE_LINK
    true
)

set(MAIN_COMPONENT
    false
)
MESSAGE("BTH_ROM_LIST:" ${BTH_ROM_LIST})
set(LIB_OUT_PATH ${BIN_DIR}/${CHIP}/libs/bluetooth/bth/${TARGET_COMMAND})

build_component()
