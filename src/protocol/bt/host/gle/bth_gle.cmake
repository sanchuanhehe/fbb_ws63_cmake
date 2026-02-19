#===============================================================================
# @brief    cmake file
# Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2022-2022. All rights reserved.
#===============================================================================
set(COMPONENT_NAME "bth_gle")

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
bt_reset_shared_list(BTH_PUBLIC_HEADER_LIST)
bt_reset_shared_list(BTH_PRIVATE_HEADER_LIST)
add_subdirectory_if_exist(host)
add_subdirectory_if_exist(ahi)
add_subdirectory_if_exist(dft)
add_subdirectory_if_exist(samples)
add_subdirectory_if_exist(sdk)
add_subdirectory_if_exist(service)
bt_get_property_or_var(BTH_RAM_LIST_RESOLVED BTH_RAM_LIST BTH_RAM_LIST)
bt_get_property_or_var(BTH_PUBLIC_HEADER_LIST_RESOLVED BTH_PUBLIC_HEADER_LIST BTH_PUBLIC_HEADER_LIST)
bt_get_property_or_var(BTH_PRIVATE_HEADER_LIST_RESOLVED BTH_PRIVATE_HEADER_LIST BTH_PRIVATE_HEADER_LIST)

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

MESSAGE("BTH_PUBLIC_HEADER_LIST=" ${BTH_PUBLIC_HEADER_LIST_RESOLVED})

set(PUBLIC_HEADER
    ${BTH_PUBLIC_HEADER_LIST_RESOLVED}
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/include/L0
    ${CMAKE_CURRENT_SOURCE_DIR}/../bg_common/include/sdk_common
)

set(PRIVATE_HEADER
    ${BTH_PRIVATE_HEADER_LIST_RESOLVED}
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
