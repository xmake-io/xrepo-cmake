#!/bin/bash

set -x
set -e

# First build.
output=cmake.log.0
cmake -DXREPO_PACKAGE_VERBOSE=ON example | tee $output
grep -E "pcre2_INCLUDE_DIR" $output
grep -E "pcre2_LINK_DIR" $output
grep -E "pcre2_LINK_LIBRARIES" $output
grep -E "pcre2_DEFINITIONS" $output
grep -E "gflags prepend to CMAKE_PREFIX_PATH" $output
grep -E "glog prepend to CMAKE_PREFIX_PATH" $output
grep -E "zlib_INCLUDE_DIR" $output
grep -E "zlib prepend to CMAKE_PREFIX_PATH" $output
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

