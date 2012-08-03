cmake_minimum_required(VERSION 2.8)
project(loginserver)

set(executable_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/main.cpp
)

set(FRAMEWORK_NET ON)
set(FRAMEWORK_SQL ON)
include(../otclient/src/framework/CMakeLists.txt)
add_executable(loginserver ${framework_SOURCES} ${executable_SOURCES})
target_link_libraries(loginserver ${framework_LIBRARIES})
