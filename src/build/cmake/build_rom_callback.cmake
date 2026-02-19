if(NOT DEFINED BUILD_ROM_CALLBACK)
    set(BUILD_ROM_CALLBACK False)
endif()
set(OBJ_TEMP_DIR "${PROJECT_BINARY_DIR}/obj_tmp")

function(rom_cb_append_extract_manifest manifest_path)
    get_property(_rom_cb_manifests GLOBAL PROPERTY ROM_CALLBACK_EXTRACT_MANIFESTS)
    if(NOT DEFINED _rom_cb_manifests OR "${_rom_cb_manifests}" STREQUAL "")
        set(_rom_cb_manifests "${manifest_path}")
    else()
        list(APPEND _rom_cb_manifests ${manifest_path})
    endif()
    set_property(GLOBAL PROPERTY ROM_CALLBACK_EXTRACT_MANIFESTS "${_rom_cb_manifests}")
endfunction()

macro(reg_rom_callback)
    if(NOT TARGET ${COMPONENT_NAME})
        set(ROM_LIB ${LIBS})
        set(DEPEND_TARGET)
    else()
        get_target_property(ORI_LIB_DIR ${COMPONENT_NAME} BINARY_DIR)
        get_target_property(CUSTOM_LIB_DIR ${COMPONENT_NAME} ARCHIVE_OUTPUT_DIRECTORY)
        if(CUSTOM_LIB_DIR)
            set(ROM_LIB ${CUSTOM_LIB_DIR}/lib${COMPONENT_NAME}.a)
        else()
            set(ROM_LIB ${ORI_LIB_DIR}/lib${COMPONENT_NAME}.a)
        endif()
        set(DEPEND_TARGET ${COMPONENT_NAME})
    endif()

    set(ROM_CB_COMPONENT_MANIFEST ${OBJ_TEMP_DIR}/${COMPONENT_NAME}.extract.manifest)
    add_custom_command(
        OUTPUT ${ROM_CB_COMPONENT_MANIFEST}
        WORKING_DIRECTORY ${OBJ_TEMP_DIR}
        COMMAND ${CMAKE_COMMAND} -E make_directory ${OBJ_TEMP_DIR}
        COMMAND ${CP} ${ROM_LIB} ${OBJ_TEMP_DIR}
        COMMAND ${CMAKE_AR} -x lib${COMPONENT_NAME}.a
        COMMAND ${CMAKE_COMMAND} -E touch ${ROM_CB_COMPONENT_MANIFEST}
        DEPENDS ${DEPEND_TARGET}
        VERBATIM
    )

    add_custom_target(GEN_ROM_CB_${COMPONENT_NAME} ALL
        DEPENDS ${ROM_CB_COMPONENT_MANIFEST}
    )

    rom_cb_append_extract_manifest(${ROM_CB_COMPONENT_MANIFEST})
endmacro()

function(build_rom_callback)
    get_property(ROM_CB_EXTRACT_MANIFESTS GLOBAL PROPERTY ROM_CALLBACK_EXTRACT_MANIFESTS)
    if(NOT DEFINED ROM_CB_EXTRACT_MANIFESTS)
        set(ROM_CB_EXTRACT_MANIFESTS)
    endif()
    set(ROM_CB_IMAGE_ELF ${PROJECT_BINARY_DIR}/${TARGET_NAME}.elf)

    set(ROM_CB_BUILD_MANIFEST ${OBJ_TEMP_DIR}/rom_callback.build.manifest)
    add_custom_command(
        OUTPUT ${ROM_CB_BUILD_MANIFEST}
        WORKING_DIRECTORY ${OBJ_TEMP_DIR}
        COMMAND ${CMAKE_COMMAND} -E make_directory ${OBJ_TEMP_DIR}
        COMMAND sh -c "if ls ./*.o* >/dev/null 2>&1; then ${CMAKE_LINKER} -r ./*.o* -o ${OBJ_TEMP_DIR}/rom_bin.o && ${CMAKE_NM} -u ${OBJ_TEMP_DIR}/rom_bin.o > rom_bin_raw.undef && ${CMAKE_READELF} -W -r ${OBJ_TEMP_DIR}/rom_bin.o > rom_bin.rel && ${CMAKE_READELF} -W -s ${OBJ_TEMP_DIR}/rom_bin.o > rom_symbol.list; else : > rom_bin_raw.undef; : > rom_bin.rel; : > rom_symbol.list; fi"
        COMMAND ${CMAKE_READELF} -W -s ${ROM_CB_IMAGE_ELF} > image_symbol.list
        COMMAND ${CMAKE_COMMAND} -E touch ${ROM_CB_BUILD_MANIFEST}
        DEPENDS ${TARGET_NAME} ${ROM_CB_EXTRACT_MANIFESTS}
        VERBATIM
    )

    add_custom_target(BUILD_ROM_CALLBACK ALL
        DEPENDS ${ROM_CB_BUILD_MANIFEST}
    )

endfunction(build_rom_callback)
