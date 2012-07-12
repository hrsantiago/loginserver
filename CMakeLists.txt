CMAKE_MINIMUM_REQUIRED(VERSION 2.6)
PROJECT(loginserver)

# CMAKE_CURRENT_LIST_DIR cmake 2.6 compatiblity
IF(${CMAKE_MAJOR_VERSION} EQUAL 2 AND ${CMAKE_MINOR_VERSION} EQUAL 6)
    GET_FILENAME_COMPONENT(CMAKE_CURRENT_LIST_DIR ${CMAKE_CURRENT_LIST_FILE} PATH)
ENDIF(${CMAKE_MAJOR_VERSION} EQUAL 2 AND ${CMAKE_MINOR_VERSION} EQUAL 6)

# add paths
SET(CMAKE_FRAMEWORK_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/../otclient/src/framework")
SET(CMAKE_OTCLIENT_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/../otclient/src/otclient")

# add framework cmake modules
SET(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../otclient/src/framework/cmake;${CMAKE_MODULE_PATH}")

# functions map for reading backtraces
SET(CMAKE_CXX_LINK_FLAGS "${CMAKE_CXX_LINK_FLAGS} -Wl,-Map=loginserver.map")

OPTION(USE_PCH "Use precompiled header (speed up compile)" OFF)
OPTION(LUAJIT "Use lua jit" OFF)

IF(NOT CMAKE_BUILD_TYPE)
    SET(CMAKE_BUILD_TYPE "RelWithDebInfo")
ENDIF()

SET(WARNS_FLAGS "-Wall -Wextra -Werror -Wno-unused-parameter -Wno-unused-but-set-variable -Wno-unused-variable")
SET(CMAKE_CXX_FLAGS                   "${CMAKE_CXX_FLAGS} ${WARNS_FLAGS} ${ARCH_FLAGS} -std=gnu++0x -pipe")
SET(CMAKE_CXX_FLAGS_DEBUG             "-O0 -ggdb")
SET(CMAKE_CXX_FLAGS_RELWITHDEBINFO    "-O1 -ggdb -fno-omit-frame-pointer")
SET(CMAKE_CXX_FLAGS_RELEASE           "-O2")
SET(CMAKE_CXX_FLAGS_PERFORMANCE       "-Ofast -mmxx -msee -msee2")
SET(CMAKE_CXX_FLAGS_MINSIZEREL        "-Os")

IF(USE_STATIC_LIBS)
    SET(CMAKE_CXX_LINK_FLAGS "-static-libgcc -static-libstdc++")
    MESSAGE(STATUS "Link to static libraries: ON")
ELSE()
    MESSAGE(STATUS "Link to static libraries: OFF")
ENDIF()

MESSAGE(STATUS "Build type: " ${CMAKE_BUILD_TYPE})
ADD_DEFINITIONS(-D"BUILD_TYPE=\\\"${CMAKE_BUILD_TYPE}\\\"")

# find needed libraries
IF(LUAJIT)
    FIND_PACKAGE(LuaJIT REQUIRED)
    SET(LUA_INCLUDE_DIR ${LUAJIT_INCLUDE_DIR})
    SET(LUA_LIBRARY ${LUAJIT_LIBRARY})
ELSE()
    FIND_PACKAGE(Lua REQUIRED)
ENDIF()
MESSAGE(STATUS "LuaJIT: " ${LUAJIT})

FIND_PACKAGE(PhysFS REQUIRED)
FIND_PACKAGE(GMP REQUIRED)

SET(executable_SOURCES
    src/main.cpp
)

INCLUDE_DIRECTORIES(
    ${LUA_INCLUDE_DIR}
    ${PHYSFS_INCLUDE_DIR}
    ${GMP_INCLUDE_DIR}
    ${ZLIB_INCLUDE_DIR}
    "${CMAKE_FRAMEWORK_SOURCE_DIR}/.."
)

SET(framework_SOURCES ${framework_SOURCES}
    # core
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/core/binarytree.cpp
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/core/binarytree.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/core/filestream.cpp
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/core/filestream.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/core/logger.cpp
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/core/logger.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/core/resourcemanager.cpp
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/core/resourcemanager.h

    ${CMAKE_FRAMEWORK_SOURCE_DIR}/core/clock.cpp
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/core/clock.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/core/event.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/core/event.cpp
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/core/eventdispatcher.cpp
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/core/eventdispatcher.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/core/timer.cpp
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/core/timer.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/core/scheduledevent.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/core/scheduledevent.cpp

    # luascript
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/luascript/declarations.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/luascript/luabinder.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/luascript/luaexception.cpp
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/luascript/luaexception.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/luascript/luainterface.cpp
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/luascript/luainterface.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/luascript/luaobject.cpp
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/luascript/luaobject.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/luascript/luavaluecasts.cpp
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/luascript/luavaluecasts.h

    # otml
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/otml/declarations.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/otml/otmldocument.cpp
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/otml/otmldocument.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/otml/otmlemitter.cpp
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/otml/otmlemitter.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/otml/otmlexception.cpp
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/otml/otmlexception.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/otml/otml.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/otml/otmlnode.cpp
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/otml/otmlnode.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/otml/otmlparser.cpp
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/otml/otmlparser.h

    # third party
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/thirdparty/lbitlib-5.2.0-backport4.cpp
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/thirdparty/lbitlib-5.2.0-backport4.h

    # util
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/util/boolean.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/util/color.cpp
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/util/color.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/util/crypt.cpp
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/util/crypt.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/util/databuffer.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/util/matrix.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/util/point.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/util/rect.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/util/rsa.cpp
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/util/rsa.h
    ${CMAKE_FRAMEWORK_SOURCE_DIR}/util/size.h
)

# add loginserver executable
ADD_EXECUTABLE(loginserver ${framework_SOURCES} ${otclient_SOURCES} ${executable_SOURCES})

# target link libraries
SET(framework_LIBRARIES
    ${LUA_LIBRARY}
    ${PHYSFS_LIBRARY}
    ${GMP_LIBRARY}
    ${ZLIB_LIBRARY}
    ${ADDITIONAL_LIBRARIES}
)

TARGET_LINK_LIBRARIES(loginserver ${framework_LIBRARIES})

IF(USE_PCH)
    include(cotire)
    cotire(loginserver)
    MESSAGE(STATUS "Use precompiled header: ON")
ELSE()
    MESSAGE(STATUS "Use precompiled header: OFF")
ENDIF()

# installation
SET(DATA_INSTALL_DIR share/loginserver)
INSTALL(TARGETS loginserver RUNTIME DESTINATION bin)
INSTALL(DIRECTORY modules DESTINATION ${DATA_INSTALL_DIR}
        PATTERN ".git" EXCLUDE)
