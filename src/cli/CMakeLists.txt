add_executable(agentsphere
    ${CMAKE_SOURCE_DIR}/src/cli/main.cpp
)

target_include_directories(agentsphere
    PRIVATE
        ${CMAKE_SOURCE_DIR}/src
        ${CMAKE_BINARY_DIR}
)

target_link_libraries(agentsphere
    PRIVATE
        tenbox_client
        nlohmann_json::nlohmann_json
)
