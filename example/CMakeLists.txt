# project
cmake_minimum_required(VERSION 3.13.0)
project(example LANGUAGES C CXX ASM)

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

# Call `xrepo_package` function to use default pcre2
xrepo_package("pcre2")

# Call `xrepo_package` function to use gflags 2.2.2 with specific configs.
xrepo_package("gflags 2.2.2"
    MODE debug
    CONFIGS "shared=true,mt=true")

xrepo_package("glog"
    CONFIGS "packages/glog.lua")

# Call `xrepo_package` function to use custom package: myzlib
set(XREPO_XMAKEFILE ${CMAKE_CURRENT_SOURCE_DIR}/packages/xmake.lua)
xrepo_package("myzlib" ALIAS zlib)

# Define target. We run cmake in example parent directory, thus we can't use
# example as target name.
add_executable(example-bin "")
target_sources(example-bin PRIVATE
    src/main.cpp
)
xrepo_target_packages(example-bin pcre2 gflags zlib)

