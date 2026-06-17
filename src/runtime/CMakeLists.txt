set(RUNTIME_SOURCES
    ${CMAKE_SOURCE_DIR}/src/runtime/main.cpp
    ${CMAKE_SOURCE_DIR}/src/runtime/runtime_service.cpp
    ${CMAKE_SOURCE_DIR}/src/runtime/crash_handler.cpp
)

if(WIN32)
    list(APPEND RUNTIME_SOURCES
        ${CMAKE_SOURCE_DIR}/src/runtime/runtime.rc
        ${CMAKE_SOURCE_DIR}/src/runtime/app.manifest
    )
endif()

add_executable(agentsphere-vm-runtime ${RUNTIME_SOURCES})

target_include_directories(agentsphere-vm-runtime
    PRIVATE
        ${CMAKE_SOURCE_DIR}/src
        ${CMAKE_BINARY_DIR}
)

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    # GNU ld resolves static archives left-to-right with no rescan. Our core
    # library references VmPlatform symbols defined in tenbox_platform, which
    # in turn depends on tenbox_core, so wrap the pair in --start-group to
    # allow cross-archive symbol resolution.
    target_link_libraries(agentsphere-vm-runtime
        PRIVATE
            -Wl,--start-group
            tenbox_platform
            tenbox_core
            -Wl,--end-group
            tenbox_ipc
    )
else()
    target_link_libraries(agentsphere-vm-runtime
        PRIVATE
            tenbox_platform
            tenbox_core
            tenbox_ipc
    )
endif()

if(WIN32)
    target_link_libraries(agentsphere-vm-runtime PRIVATE ws2_32 dbghelp)
elseif(APPLE)
    target_link_libraries(agentsphere-vm-runtime PRIVATE
        "-framework Hypervisor"
        "-framework Foundation"
    )

    # Auto-sign with hypervisor entitlement after every build
    set(ENTITLEMENTS_FILE "${CMAKE_SOURCE_DIR}/runtime.entitlements")
    add_custom_command(TARGET agentsphere-vm-runtime POST_BUILD
        COMMAND codesign --force --sign - --entitlements "${ENTITLEMENTS_FILE}"
                "$<TARGET_FILE:agentsphere-vm-runtime>"
        COMMENT "Signing agentsphere-vm-runtime with hypervisor entitlement"
    )
elseif(UNIX)
    target_link_libraries(agentsphere-vm-runtime PRIVATE pthread)
endif()
