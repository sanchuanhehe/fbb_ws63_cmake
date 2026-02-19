#===============================================================================
# @brief    cmake file
# Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2023-2023. All rights reserved.
#===============================================================================
set(MODULE_NAME "bt")
set(AUTO_DEF_FILE_ID FALSE)
set(COMPONENT_NAME "sle_netdev")

function(chba_get_property_or_var out_var property_name fallback_var)
    get_property(_value GLOBAL PROPERTY ${property_name})
    if((NOT DEFINED _value OR "${_value}" STREQUAL "") AND DEFINED ${fallback_var})
        set(_value "${${fallback_var}}")
    endif()
    set(${out_var} "${_value}" PARENT_SCOPE)
endfunction()

macro(chba_reset_shared_list list_name)
    set_property(GLOBAL PROPERTY ${list_name} "")
    set(${list_name} "")
endmacro()

chba_reset_shared_list(CHBA_NETDEV_LIST)
chba_reset_shared_list(CHBA_NETDEV_HEADER_LIST)

add_subdirectory_if_exist(sle_netdev)

chba_get_property_or_var(CHBA_NETDEV_LIST_RESOLVED CHBA_NETDEV_LIST CHBA_NETDEV_LIST)
chba_get_property_or_var(CHBA_NETDEV_HEADER_LIST_RESOLVED CHBA_NETDEV_HEADER_LIST CHBA_NETDEV_HEADER_LIST)

set(PUBLIC_DEFINES
)

# use this when you want to add ccflags like -include xxx
set(COMPONENT_PUBLIC_CCFLAGS
)

set(COMPONENT_CCFLAGS
    -Wmissing-declarations -Wundef  -Wmissing-prototypes -Wswitch-default
)

set(WHOLE_LINK
    true
)

set(MAIN_COMPONENT
    false
)

set(SOURCES
    ${CHBA_NETDEV_LIST_RESOLVED}
)

set(PUBLIC_HEADER
    ${CHBA_NETDEV_HEADER_LIST_RESOLVED}
    ${CMAKE_CURRENT_SOURCE_DIR}/comm/
)

set(PRIVATE_HEADER
    ${ROOT_DIR}/include
    ${ROOT_DIR}/drivers/chips/ws53/arch/include
    ${CHBA_NETDEV_HEADER_LIST_RESOLVED}
)

if("${CHBA_NETDEV_LIST_RESOLVED}" STREQUAL "")
    set(LIBS ${CMAKE_CURRENT_SOURCE_DIR}/${TARGET_COMMAND}/lib${COMPONENT_NAME}.a)
endif()

set(LIB_OUT_PATH ${BIN_DIR}/${CHIP}/libs/bluetooth/chba/${TARGET_COMMAND})
build_component()

set(COMPONENT_NAME "chba_at")
chba_reset_shared_list(CHBA_AT_LIST)
chba_reset_shared_list(CHBA_AT_HEADER_LIST)

add_subdirectory_if_exist(at)

chba_get_property_or_var(CHBA_AT_LIST_RESOLVED CHBA_AT_LIST CHBA_AT_LIST)
chba_get_property_or_var(CHBA_AT_HEADER_LIST_RESOLVED CHBA_AT_HEADER_LIST CHBA_AT_HEADER_LIST)

set(PUBLIC_DEFINES
)

# use this when you want to add ccflags like -include xxx
set(COMPONENT_PUBLIC_CCFLAGS
)

set(COMPONENT_CCFLAGS
    -Wmissing-declarations -Wundef  -Wmissing-prototypes -Wswitch-default
)

set(WHOLE_LINK
    true
)

set(MAIN_COMPONENT
    false
)

set(SOURCES
    ${CHBA_AT_LIST_RESOLVED}
)

set(PUBLIC_HEADER
    ${CHBA_AT_HEADER_LIST_RESOLVED}
)

set(PRIVATE_HEADER
    ${CMAKE_CURRENT_SOURCE_DIR}/comm/
)

if("${CHBA_AT_LIST_RESOLVED}" STREQUAL "")
    set(LIBS ${CMAKE_CURRENT_SOURCE_DIR}/${TARGET_COMMAND}/lib${COMPONENT_NAME}.a)
endif()
set(LIB_OUT_PATH ${BIN_DIR}/${CHIP}/libs/bluetooth/chba/${TARGET_COMMAND})
build_component()
