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
    CONFIGS "shared=true,mt=true")

xrepo_package("glog"
    # xrepo_package("gflags") would be unnecessary if we use DEPS to include dependent libraries.
    #DEPS
    CONFIGS "packages/glog.lua")

# find_pacakge works because package install dir is added to CMAKE_PREFIX_PATH.
find_package(gflags)
find_package(glog)

# Call `xrepo_package` function to use custom package: myzlib
set(XREPO_XMAKEFILE ${CMAKE_CURRENT_SOURCE_DIR}/packages/xmake.lua)
xrepo_package("myzlib" ALIAS zlib)

# Define target. We run cmake in example parent directory, thus we can't use
# example as target name.
add_executable(example-bin "")
target_sources(example-bin PRIVATE
    src/main.cpp
)
# For packges that does not provide cmake config-file packages,
# xrepo_target_packges is convenient to setup include, library path and link targets.
# We can specify multiple packages in a single call.
#xrepo_target_packages(example-bin pcre2 zlib)

xrepo_target_packages(example-bin pcre2)
# NO_LINK_LIBRARIES does not call target_link_libraries. User can select which lib to link with.
xrepo_target_packages(example-bin zlib NO_LINK_LIBRARIES)
target_link_libraries(example-bin PRIVATE z)
# For packages that provide config-file packages, we can still use imported
# targets for linking. glog::glog has dependency on gflags, thus not needed
# here.
target_link_libraries(example-bin PRIVATE glog::glog)

# This is for testing pkgconfig path settings.
find_package(PkgConfig)
pkg_check_modules(pcre2 libpcre2-posix)
message(STATUS "pkg_check_modules pcre2_CFLAGS: ${pcre2_CFLAGS}")

