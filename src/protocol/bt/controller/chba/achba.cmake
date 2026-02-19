#===============================================================================
# @brief    cmake file
# Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2023-2023. All rights reserved.
#===============================================================================
set(MODULE_NAME "bt")
set(AUTO_DEF_FILE_ID FALSE)
set(COMPONENT_NAME "achba")

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

add_subdirectory_if_exist(achba)

chba_get_property_or_var(ACHBA_LIST_RESOLVED ACHBA_LIST ACHBA_LIST)
chba_get_property_or_var(ACHBA_HEADER_LIST_RESOLVED ACHBA_HEADER_LIST ACHBA_HEADER_LIST)

set(PUBLIC_DEFINES
    ACHBA_SUPPORT
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

if("${ACHBA_LIST_RESOLVED}" STREQUAL "")
    set(ACHBA_LIST_RESOLVED "__null__")
endif()

set(SOURCES
    ${ACHBA_LIST_RESOLVED}
)

set(PUBLIC_HEADER
    ${ACHBA_HEADER_LIST_RESOLVED}
)

set(PRIVATE_HEADER
    ${ROOT_DIR}/include
    ${ROOT_DIR}/drivers/chips/ws53/arch/include
    ${CMAKE_CURRENT_SOURCE_DIR}/comm/
    ${ROOT_DIR}/open_source/lwip/lwip_v2.1.3/src/include/
    ${ROOT_DIR}/open_source/lwip/lwip_adapt/src/include/
    ${ROOT_DIR}/middleware/utils/common_headers/osal/
    ${ACHBA_HEADER_LIST_RESOLVED}
)

set(LIB_OUT_PATH ${BIN_DIR}/${CHIP}/libs/bluetooth/chba/${TARGET_COMMAND})
build_component()
