#!/bin/bash

set -x
set -e

rm -rf CMakeCache.txt CMakeFiles/ cmake_install.cmake

# First build.
output=cmake.log.0
cmake -DXREPO_PACKAGE_VERBOSE=ON example | tee $output
grep -E 'mode=debug pcre2' $output
grep -E "pcre2_INCLUDE_DIRS" $output
grep -E "pcre2_LIBRARY_DIRS" $output
grep -E "pcre2_LIBRARIES" $output
grep -E "pcre2_DEFINITIONS" $output
grep -E "gflags prepend to CMAKE_PREFIX_PATH" $output
grep -E "glog prepend to CMAKE_PREFIX_PATH" $output
grep -E "zlib_INCLUDE_DIRS" $output
grep -E "zlib prepend to CMAKE_PREFIX_PATH" $output
grep -E "pkg_check_modules pcre2_CFLAGS.*packages/p/pcre2" $output
grep -E "target_link_libraries\(example-bin PRIVATE pcre2-posix;pcre2-8\)" $output
grep -v -E "xrepo: target_link_libraries\(example-bin PRIVATE z\)" $output
make

# Check for cached variables.
output=make.log.1
touch example/CMakeLists.txt
make | tee $output

match_cached_output="already installed, using cached variables"

grep -E "pcre2 $match_cached_output" $output
grep -E "gflags 2.2.2 $match_cached_output" $output
grep -E "glog $match_cached_output" $output
grep -E "myzlib $match_cached_output" $output

# Check for update of config lua script.
output=make.log.2
touch example/packages/glog.lua
make | tee $output
grep -E "pcre2 $match_cached_output" $output
grep -E "gflags 2.2.2 $match_cached_output" $output
grep -E "example/packages/glog.lua" $output
grep -E "myzlib $match_cached_output" $output

