#===============================================================================
# @brief    cmake file
# Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd.. 2023. All rights reserved.
#===============================================================================
set(COMPONENT_NAME "bt_app")

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

bt_reset_shared_list(BTA_RAM_LIST)
bt_reset_shared_list(BTH_PUBLIC_HDR_LIST)
bt_reset_shared_list(BTH_PRIVATE_HDR_LIST)

if(${CHIP} MATCHES "ws63|bs20|bs21|bs21e|bs21a|bs22|bs26") # 单双核差异
    add_subdirectory_if_exist(dft)
    add_subdirectory_if_exist(service)
    add_subdirectory_if_exist(ahi/ahi_a)
else()
    add_subdirectory_if_exist(dft)
    add_subdirectory_if_exist(service)
    add_subdirectory_if_exist(ahi/ahi_a)
endif()

# for sdk closed_component compile
bt_get_property_or_var(BTA_RAM_LIST_RESOLVED BTA_RAM_LIST BTA_RAM_LIST)
bt_get_property_or_var(BTH_PUBLIC_HDR_LIST_RESOLVED BTH_PUBLIC_HDR_LIST BTH_PUBLIC_HDR_LIST)
bt_get_property_or_var(BTH_PRIVATE_HDR_LIST_RESOLVED BTH_PRIVATE_HDR_LIST BTH_PRIVATE_HDR_LIST)

if("${BTA_RAM_LIST_RESOLVED}" STREQUAL "")
    if(DEFINED CONFIG_SLE_BLE_SUPPORT AND SUPPORT_MULTI_LIBS IN_LIST DEFINES)
        set(LIBS ${CMAKE_CURRENT_SOURCE_DIR}/${CHIP}-${CONFIG_SLE_BLE_SUPPORT}/lib${COMPONENT_NAME}.a)
    elseif(DEFINED CONFIG_SUPPORT_SLE_BLE_CENTRAL_DEFAULT)
        set(LIBS ${CMAKE_CURRENT_SOURCE_DIR}/${TARGET_COMMAND}/lib${COMPONENT_NAME}.a)
    else()
        set(SOURCES "__null__")
    endif()
else()
    set(SOURCES
        ${BTA_RAM_LIST_RESOLVED}
    )
    set(LOG_DEF
        ${CMAKE_CURRENT_SOURCE_DIR}/../bg_common/include/log/log_def_sdk_bth.h
    )
endif()
if(${CHIP} MATCHES "ws53|ws63|bs20|bs21|bs21e|bs21a|bs22|bs26|bs25")
    set(PUBLIC_HEADER
        ${BTH_PUBLIC_HDR_LIST_RESOLVED}
        ${CMAKE_CURRENT_SOURCE_DIR}/host/inc
        ${CMAKE_CURRENT_SOURCE_DIR}/include/ble
        ${CMAKE_CURRENT_SOURCE_DIR}/include/ble/L0
    )
else()
    set(PUBLIC_HEADER
        ${BTH_PUBLIC_HDR_LIST_RESOLVED}
        ${CMAKE_CURRENT_SOURCE_DIR}/host/inc
        ${CMAKE_CURRENT_SOURCE_DIR}/include/ble
        ${CMAKE_CURRENT_SOURCE_DIR}/include/ble/L0
        ${CMAKE_CURRENT_SOURCE_DIR}/include/br/L0
    )
endif()

set(PRIVATE_HEADER
    ${PRIVATE_HEADER}
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

set(LIB_OUT_PATH ${BIN_DIR}/${CHIP}/libs/bluetooth/bth/${TARGET_COMMAND})

build_component()
