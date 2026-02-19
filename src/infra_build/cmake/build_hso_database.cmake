#===============================================================================
# @brief    cmake component build
# Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2022-2022. All rights reserved.
#===============================================================================

add_custom_target(HSO_DB
    COMMENT "Generating HSO_DB ${TARGET_NAME}"
)
if(DEFINED LOG_CUSTOM_ENABLE)
    if(${LOG_CUSTOM_ENABLE} STREQUAL True)
        include(${CMAKE_SOURCE_DIR}/infra_build/script/hdbxml_custom/MessageXmlGen/messagexmlgen.cmake)
    endif()
endif()

function(hso_get_global_or_var out_var property_name fallback_var)
    get_property(_value GLOBAL PROPERTY ${property_name})
    if((NOT DEFINED _value OR "${_value}" STREQUAL "") AND DEFINED ${fallback_var})
        set(_value "${${fallback_var}}")
    endif()
    set(${out_var} "${_value}" PARENT_SCOPE)
endfunction()

function(hso_get_component_meta out_var component_name key_name)
    get_property(_meta_value GLOBAL PROPERTY COMPONENT_META_${component_name}_${key_name})
    if((NOT DEFINED _meta_value OR "${_meta_value}" STREQUAL "") AND DEFINED ${component_name}_${key_name})
        set(_meta_value "${${component_name}_${key_name}}")
    endif()
    set(${out_var} "${_meta_value}" PARENT_SCOPE)
endfunction()

function(create_hso_db)
    if(DEFINED HSO_XML_CHIP)
        set(XML_CHIP ${HSO_XML_CHIP})
    else()
        set(XML_CHIP ${CHIP})
    endif()

    set(XML_FILE ${ROOT_DIR}/infra_build/config/target_config/${XML_CHIP}/hdb_config/database_template/acore/system/hdbcfg/mss_cmd_db.xml)
    set(HSO_DB_MKDIR_MANIFEST ${PROJECT_BINARY_DIR}/hso_temp/mkdir.manifest)
    add_custom_command(
        OUTPUT ${HSO_DB_MKDIR_MANIFEST}
        COMMAND ${Python3_EXECUTABLE} ${MAK_HSO_XML} mkdir ${ROOT_DIR}/ ${XML_CHIP} ${CORE}
        COMMAND ${CMAKE_COMMAND} -E touch ${HSO_DB_MKDIR_MANIFEST}
        COMMENT "HSO_DB Makedir"
        VERBATIM
    )
    add_custom_target(HSO_DB_MKDIR
        DEPENDS ${HSO_DB_MKDIR_MANIFEST}
    )

    if(DEFINED LOG_CUSTOM_ENABLE)
        if(${LOG_CUSTOM_ENABLE} STREQUAL True)
            build_xml()
        endif()
    endif()

    hso_get_global_or_var(LOG_DEF_LIST_RESOLVED LOG_DEF_LIST LOG_DEF_LIST)
    set(HSO_DB_COMPONENT_OUTPUTS)

    foreach(COMPONENT ${TARGET_COMPONENT})
        hso_get_component_meta(COMPONENT_SOURCES_RESOLVED ${COMPONENT} SOURCES)
        hso_get_component_meta(COMPONENT_AUTO_DEF_RESOLVED ${COMPONENT} AUTO_DEF)
        hso_get_component_meta(COMPONENT_MODULE_NAME_RESOLVED ${COMPONENT} MODULE_NAME)

        if("${COMPONENT_SOURCES_RESOLVED}" STREQUAL "")
            continue()
        endif()

        set(CLOSED_FLAG "False")
        check_if_closed_component(${COMPONENT})
        if (${COMPONENT_IS_CLOSED})
            set(CLOSED_FLAG "True")
        endif()
        list(JOIN LOG_DEF_LIST_RESOLVED "," LOG_DEF)
        list(JOIN COMPONENT_SOURCES_RESOLVED "," SOURCE)
        # for windows command length limit
        file(WRITE "${PROJECT_BINARY_DIR}/hso_temp/${COMPONENT}_temp.txt" "${LOG_DEF}####${SOURCE}")
        add_custom_command(
            OUTPUT ${PROJECT_BINARY_DIR}/hso_temp/${COMPONENT}.txt
            # for re-run HDB
            COMMAND ${CP} ${PROJECT_BINARY_DIR}/hso_temp/${COMPONENT}_temp.txt ${PROJECT_BINARY_DIR}/hso_temp/${COMPONENT}.txt
            COMMAND ${Python3_EXECUTABLE} ${MAK_HSO_XML} ${ROOT_DIR}/ ${XML_CHIP} ${CORE} ${ARCH} ${COMPONENT_AUTO_DEF_RESOLVED} ${COMPONENT_MODULE_NAME_RESOLVED} ${CLOSED_FLAG} ${PROJECT_BINARY_DIR}/hso_temp/${COMPONENT}.txt
            COMMENT "Building HSO_DB_${COMPONENT}"
            DEPENDS ${COMPONENT_SOURCES_RESOLVED} ${LOG_DEF_LIST_RESOLVED} ${HSO_DB_MKDIR_MANIFEST}
            VERBATIM
        )
        list(APPEND HSO_DB_COMPONENT_OUTPUTS ${PROJECT_BINARY_DIR}/hso_temp/${COMPONENT}.txt)
        add_custom_target(HSO_DB_${COMPONENT}
            DEPENDS ${PROJECT_BINARY_DIR}/hso_temp/${COMPONENT}.txt
        )
        add_dependencies(HSO_DB HSO_DB_${COMPONENT})
    endforeach ()
    if(NOT DEFINED HSO_ENABLE_BT)
        set(HSO_ENABLE_BT FALSE)
    endif()
    if(${CORE} STREQUAL "bt_core" OR ${HSO_ENABLE_BT} STREQUAL "True")
        set(HSO_DB_BT_STATUS_MANIFEST ${PROJECT_BINARY_DIR}/hso_temp/bt_status.manifest)
        add_custom_command(
            OUTPUT ${HSO_DB_BT_STATUS_MANIFEST}
            COMMAND ${Python3_EXECUTABLE} ${BT_STATUS_HSO_XML} ${ROOT_DIR}/ ${XML_CHIP}
            COMMAND ${Python3_EXECUTABLE} ${OTA_MSG_HSO_XML}   ${ROOT_DIR}/ ${XML_CHIP}
            COMMAND ${CMAKE_COMMAND} -E touch ${HSO_DB_BT_STATUS_MANIFEST}
            VERBATIM
        )
        add_custom_target(HSO_DB_BT_STATUS
            DEPENDS ${HSO_DB_BT_STATUS_MANIFEST}
        )
        add_dependencies(HSO_DB HSO_DB_BT_STATUS)
    else()
        set(HSO_DB_BT_STATUS_MANIFEST)
    endif()

    set(HSO_DB_MERGE_MANIFEST ${PROJECT_BINARY_DIR}/hso_temp/merge_db.manifest)
    add_custom_command(
        OUTPUT ${HSO_DB_MERGE_MANIFEST}
        COMMAND ${Python3_EXECUTABLE} ${HSO_XML_PRE_PROCESS} ${ROOT_DIR}/ ${XML_CHIP} ${CORE}
        COMMAND ${Python3_EXECUTABLE} ${HSO_XML_MERGE} ${ROOT_DIR}/ ${XML_CHIP} ${CORE} "${HSO_ENABLE_BT}"
        COMMAND ${Python3_EXECUTABLE} ${HSO_XML_DB_CREATE} ${ROOT_DIR}/ ${XML_CHIP}
        COMMAND ${CMAKE_COMMAND} -E touch ${HSO_DB_MERGE_MANIFEST}
        COMMENT "Merge HSO_XML & Create HSO_DB"
        DEPENDS ${HSO_DB_COMPONENT_OUTPUTS} ${HSO_DB_BT_STATUS_MANIFEST} ${HSO_DB_MKDIR_MANIFEST}
        VERBATIM
    )
    add_custom_target(HSO_DB_MERGE
        DEPENDS ${HSO_DB_MERGE_MANIFEST}
    )
    if(NOT DEFINED GEN_PARSE_TOOL)
        set(HSO_ENABLE_BT FALSE)
    endif()

    if("${GEN_PARSE_TOOL}" STREQUAL "True")
        set(INFO_FILE ${PROJECT_BINARY_DIR}/${BIN_NAME}.info)
        set(NM_FILE ${PROJECT_BINARY_DIR}/${BIN_NAME}.nm)
        set(PARSE_TOOL_DIR "${PROJECT_BINARY_DIR}/parse_tool")
        set(HSO_DB_PARSE_MANIFEST ${PROJECT_BINARY_DIR}/hso_temp/parse_tool.manifest)
        add_custom_command(
            OUTPUT ${HSO_DB_PARSE_MANIFEST}
            COMMAND ${Python3_EXECUTABLE} ${HSO_PARSE_MAIN} ${PARSE_TOOL_DIR} ${INFO_FILE} ${NM_FILE} ${XML_FILE}
            COMMAND ${CP_PY} ${HSO_PARSE_DIR}/ ${PARSE_TOOL_DIR} "none" *.py
            COMMAND ${CMAKE_COMMAND} -E touch ${HSO_DB_PARSE_MANIFEST}
            DEPENDS ${HSO_DB_MERGE_MANIFEST} ${INFO_FILE} ${NM_FILE} ${XML_FILE}
            VERBATIM
        )
        add_custom_target(HSO_DB_PARSE
            DEPENDS ${HSO_DB_PARSE_MANIFEST}
        )
        add_dependencies(HSO_DB HSO_DB_PARSE)
    else()
        add_dependencies(HSO_DB HSO_DB_MERGE)
    endif()
endfunction(create_hso_db)
