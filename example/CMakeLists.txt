# project
cmake_minimum_required(VERSION 3.13.0)
project(example LANGUAGES C CXX ASM)

if("$ENV{CI}" MATCHES "true")
# For CI build, use code inside repo.
include(${CMAKE_SOURCE_DIR}/../xrepo.cmake)
else()
# Download xrepo.cmake if not exists in build directory.
if(NOT EXISTS "${CMAKE_BINARY_DIR}/xrepo.cmake")
    message(STATUS "Downloading xrepo.cmake from https://github.com/xmake-io/xrepo-cmake/")
    # mirror https://cdn.jsdelivr.net/gh/xmake-io/xrepo-cmake@main/xrepo.cmake
    file(DOWNLOAD "https://raw.githubusercontent.com/xmake-io/xrepo-cmake/main/xrepo.cmake"
                  "${CMAKE_BINARY_DIR}/xrepo.cmake"
                  TLS_VERIFY ON)
endif()

# Include xrepo.cmake so we can use xrepo_package function.
include(${CMAKE_BINARY_DIR}/xrepo.cmake)
endif()

# Call `xrepo_package` function to use gflags 2.2.2 with specific configs.
xrepo_package("gflags 2.2.2"
    MODE debug
    CONFIGS "shared=true,mt=true"
    OUTPUT diagnosis)

# `xrepo_package` sets `gflags_DIR` variable in parent scope because gflags
# provides cmake modules. So we can now call `find_package` to find gflags
# package.
find_package(gflags CONFIG COMPONENTS shared)

# Define target
add_executable(example "")
target_sources(example PRIVATE
    src/main.cpp
)
