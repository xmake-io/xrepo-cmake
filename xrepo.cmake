option(XREPO_PACKAGE_DISABLE "Disable Xrepo Packages" OFF)
option(XREPO_PACKAGE_VERBOSE "Enable verbose output for Xrepo Packages" OFF)
option(XREPO_BOOTSTRAP_XMAKE "Bootstrap Xmake automatically" ON)

# Following options are for cross compilation, or when specifying a specific compiler.
set(XREPO_PLATFORM "" CACHE STRING "Xrepo package platform")
set(XREPO_ARCH "" CACHE STRING "Xrepo package architecture")
set(XREPO_TOOLCHAIN "" CACHE STRING "Xrepo package toolchain")
set(XREPO_XMAKEFILE "" CACHE STRING "Xmake script file of Xrepo package")

# xrepo_package:
#
# Parameters:
#      package_spec: required
#          The package name and version recognized by xrepo.
#      CONFIGS: optional
#          Run `xrepo info <package>` to see what configs are available.
#      MODE: optional, debug|release
#          If not specified: mode is set to "debug" only when $CMAKE_BUILD_TYPE
#          is Debug. Otherwise mode is `release`.
#      OUTPUT: optional, verbose|diagnosis|quiet
#          Control output for xrepo install command.
#      DIRECTORY_SCOPE: optional
#          If specified, setup include and link directories for the package in
#          CMake directory scope. CMake code in `add_subdirectory` can also use
#          the package directly.
#
# Example:
#
#      xrepo_package(
#          "foo 1.2.3"
#          [CONFIGS feature1=true,feature2=false]
#          [MODE debug|release]
#          [OUTPUT verbose|diagnosis|quiet]
#          [DIRECTORY_SCOPE]
#      )
#
# `xrepo_package` does the following tasks for the above call:
#
# 1. Ensure specified package `foo` version 1.2.3 with given config is installed.
# 2. Set variable `foo_INCLUDE_DIR` and `foo_LINK_DIR` to header and library
#     path.
#     -    Use these variables in `target_include_directories` and
#       `target_link_directories` to use the package.
#     - User should figure out what library to use for `target_link_libraries`.
#     - If `DIRECTORY_SCOPE` is specified, execute following code so the package
#       can be used in cmake's direcotry scope:
#           include_directories(foo_INCLUDE_DIR)
#           link_directories(foo_LINK_DIR)
# 3. If package provides cmake modules under `${foo_LINK_DIR}/cmake/foo`,
#     set `foo_DIR` to the module directory so that `find_package(foo)`
#     can be used.
function(_install_xmake_program)
    set(XMAKE_BINARY_DIR ${CMAKE_BINARY_DIR}/xmake)
    message(STATUS "xmake not found, Install it to ${XMAKE_BINARY_DIR} automatically!")
    if(EXISTS "${XMAKE_BINARY_DIR}")
        file(REMOVE_RECURSE ${XMAKE_BINARY_DIR})
    endif()

    # Download xmake archive file
    set(XMAKE_VERSION master)
    set(XMAKE_RELEASE_LATEST v2.6.3)
    if(WIN32)
        set(XMAKE_ARCHIVE_FILE ${CMAKE_BINARY_DIR}/xmake-${XMAKE_VERSION}.win32.zip)
        set(XMAKE_ARCHIVE_URL https://github.com/xmake-io/xmake/releases/download/${XMAKE_RELEASE_LATEST}/xmake-${XMAKE_VERSION}.win32.zip)
    else()
        set(XMAKE_ARCHIVE_FILE ${CMAKE_BINARY_DIR}/xmake-${XMAKE_VERSION}.zip)
        set(XMAKE_ARCHIVE_URL https://github.com/xmake-io/xmake/releases/download/${XMAKE_RELEASE_LATEST}/xmake-${XMAKE_VERSION}.zip)
    endif()
    if(NOT EXISTS "${XMAKE_ARCHIVE_FILE}")
        message(STATUS "Downloading xmake from ${XMAKE_ARCHIVE_URL}")
        file(DOWNLOAD "${XMAKE_ARCHIVE_URL}"
                      "${XMAKE_ARCHIVE_FILE}"
                      TLS_VERIFY ON)
    endif()

    # Extract xmake archive file
    if(NOT EXISTS "${XMAKE_BINARY_DIR}")
        message(STATUS "Extracting ${XMAKE_ARCHIVE_FILE}")
        file(MAKE_DIRECTORY ${XMAKE_BINARY_DIR})
        execute_process(COMMAND ${CMAKE_COMMAND} -E tar xzf ${XMAKE_ARCHIVE_FILE}
            WORKING_DIRECTORY ${XMAKE_BINARY_DIR}
            RESULT_VARIABLE exit_code)
        if(NOT "${exit_code}" STREQUAL "0")
            message(FATAL_ERROR "unzip ${XMAKE_ARCHIVE_FILE} failed, exit code: ${exit_code}")
        endif()
    endif()

    # Install xmake
    if(WIN32)
        set(XMAKE_BINARY ${XMAKE_BINARY_DIR}/xmake/xmake.exe)
        if(EXISTS ${XMAKE_BINARY})
            set(XMAKE_CMD ${XMAKE_BINARY} PARENT_SCOPE)
        endif()
    else()
        message(STATUS "Building xmake")
        execute_process(COMMAND make
            WORKING_DIRECTORY ${XMAKE_BINARY_DIR}
            RESULT_VARIABLE exit_code)
        if(NOT "${exit_code}" STREQUAL "0")
            message(FATAL_ERROR "Build xmake failed, exit code: ${exit_code}")
        endif()

        message(STATUS "Installing xmake")
        execute_process(COMMAND make install PREFIX=${XMAKE_BINARY_DIR}/install
            WORKING_DIRECTORY ${XMAKE_BINARY_DIR}
            RESULT_VARIABLE exit_code)
        if(NOT "${exit_code}" STREQUAL "0")
            message(FATAL_ERROR "Install xmake failed, exit code: ${exit_code}")
        endif()

        set(XMAKE_BINARY ${XMAKE_BINARY_DIR}/install/bin/xmake)
        if(EXISTS ${XMAKE_BINARY})
            set(XMAKE_CMD ${XMAKE_BINARY} PARENT_SCOPE)
        endif()
    endif()
endfunction()

macro(_detect_xmake_cmd)
    if(NOT XMAKE_CMD)
        # Note: if XMAKE_CMD is already defined, find_program does not search.
        # find_program makes XMAKE_CMD a cached variable. So find_program
        # searches only once for each cmake build directory.
        find_program(XMAKE_CMD xmake)
    endif()

    if(NOT XMAKE_CMD)
        if(WIN32)
            set(XMAKE_BINARY ${CMAKE_BINARY_DIR}/xmake/xmake/xmake.exe)
        else()
            set(XMAKE_BINARY ${CMAKE_BINARY_DIR}/xmake/install/bin/xmake)
        endif()
        if(EXISTS ${XMAKE_BINARY})
            set(XMAKE_CMD ${XMAKE_BINARY})
        endif()
    endif()
    if(NOT XMAKE_CMD AND XREPO_BOOTSTRAP_XMAKE)
        _install_xmake_program()
    endif()
    if(NOT XMAKE_CMD)
        message(FATAL_ERROR "xmake not found, Please install it first from https://xmake.io")
    endif()

    message(STATUS "xmake command: ${XMAKE_CMD}")
    set(XREPO_CMD ${XMAKE_CMD} lua private.xrepo)
endmacro()

function(_xrepo_detect_json_support)
    if(DEFINED XREPO_FETCH_JSON)
        return()
    endif()

    # Whether to use `xrepo fetch --json` to get package info.
    set(use_fetch_json ON)

    if(${CMAKE_VERSION} VERSION_LESS "3.19")
        message(WARNING "CMake version < 3.19 has no JSON support, "
                        "xrepo_package maybe unreliable to setup package variables")
        set(use_fetch_json OFF)
    elseif(XREPO_CMD)
        execute_process(COMMAND ${XREPO_CMD} fetch --help
                        OUTPUT_VARIABLE help_output
                        RESULT_VARIABLE exit_code)
        if(NOT "${exit_code}" STREQUAL "0")
            message(FATAL_ERROR "xrepo fetch --help failed, exit code: ${exit_code}")
        endif()

        if(NOT "${help_output}" MATCHES "--json")
            message(WARNING "xrepo fetch does not support --json (please upgrade), "
                            "xrepo_package maybe unreliable to setup package variables")
            set(use_fetch_json OFF)
        endif()
    endif()

    set(XREPO_FETCH_JSON ${use_fetch_json} CACHE BOOL "Use xrepo JSON output" FORCE)
endfunction()

if(NOT XREPO_PACKAGE_DISABLE)
    # Setup for xmake.
    _detect_xmake_cmd()
    _xrepo_detect_json_support()
    message(STATUS "xrepo fetch --json: ${XREPO_FETCH_JSON}")
endif()

function(xrepo_package package)
    if(XREPO_PACKAGE_DISABLE)
        return()
    endif()

    set(options DIRECTORY_SCOPE)
    set(one_value_args CONFIGS MODE OUTPUT ALIAS)
    cmake_parse_arguments(ARG "${options}" "${one_value_args}" "" ${ARGN})

    # Construct options to xrepo install and fetch command.
    if(DEFINED ARG_CONFIGS)
        set(configs "--configs=${ARG_CONFIGS}")
    else()
        set(configs "")
    endif()

    if(DEFINED ARG_MODE)
        _validate_mode(${ARG_MODE})
        set(mode "--mode=${ARG_MODE}")
    else()
        string(TOLOWER "${CMAKE_BUILD_TYPE}" _cmake_build_type)
        if(_cmake_build_type STREQUAL "debug")
            set(mode "--mode=debug")
        else()
            set(mode "--mode=release")
        endif()
    endif()

    if(XREPO_PACKAGE_VERBOSE)
        set(verbose "-vD")
    elseif(DEFINED ARG_OUTPUT)
        string(TOLOWER "${ARG_OUTPUT}" _output)
        if(_output STREQUAL "diagnosis")
            set(verbose "-vD")
        elseif(_output STREQUAL "verbose")
            set(verbose "-v")
        elseif(_output STREQUAL "quiet")
            set(verbose "-q")
        endif()
    endif()

    # Options for cross compilation and toolchain.
    if(NOT "${XREPO_PLATFORM}" STREQUAL "")
        set(platform "--plat=${XREPO_PLATFORM}")
    endif()
    if(NOT "${XREPO_ARCH}" STREQUAL "")
        set(arch "--arch=${XREPO_ARCH}")
    endif()
    if(NOT "${XREPO_TOOLCHAIN}" STREQUAL "")
        set(toolchain "--toolchain=${XREPO_TOOLCHAIN}")
        if("${XREPO_PLATFORM}" STREQUAL "")
            set(platform "--plat=cross")
            message(STATUS "xrepo: setting platform to cross because toolchain is specified")
        endif()
    endif()
    if(NOT "${XREPO_XMAKEFILE}" STREQUAL "")
        set(includes "--includes=${XREPO_XMAKEFILE}")
    endif()

    # Get package_name that will be used as various variables' prefix.
    if(DEFINED ARG_ALIAS)
        _xrepo_package_name(${ARG_ALIAS})
    else()
        _xrepo_package_name(${package})
    endif()

    # To speedup cmake re-configure, if xrepo command args is the same as the
    # cached value, load related variables from cache to avoid executing xrepo
    # command again.
    set(_xrepo_cmdargs_${package_name} "${XREPO_CMD} ${verbose} ${platform} ${arch} ${toolchain} ${includes} ${mode} ${configs} ${package}")
    if("${_cache_xrepo_cmdargs_${package_name}}" STREQUAL "${_xrepo_cmdargs_${package_name}}")
        message(STATUS "xrepo: ${package} already installed, using cached variables")

        foreach(var ${_cache_xrepo_vars_${package_name}})
            message(STATUS "xrepo: ${var} ${${var}}")
        endforeach()

        if(ARG_DIRECTORY_SCOPE)
            _xrepo_directory_scope(${package_name})
        endif()

        return()
    endif()

    message(STATUS "xrepo install ${verbose} ${platform} ${arch} ${toolchain} ${includes} ${mode} ${configs} '${package}'")
    execute_process(COMMAND ${XREPO_CMD} install --yes ${verbose} ${platform} ${arch} ${toolchain} ${includes} ${mode} ${configs} ${package}
                    RESULT_VARIABLE exit_code)
    if(NOT "${exit_code}" STREQUAL "0")
        message(FATAL_ERROR "xrepo install failed, exit code: ${exit_code}")
    endif()

    if(XREPO_FETCH_JSON)
        _xrepo_fetch_json()
    else()
        _xrepo_fetch_cflags()
    endif()

    if(ARG_DIRECTORY_SCOPE)
        _xrepo_directory_scope(${package_name})
    endif()

    # Store xrepo command and arguments for furture comparison.
    set(_cache_xrepo_cmdargs_${package_name} "${_xrepo_cmdargs_${package_name}}" CACHE INTERNAL "")
endfunction()

function(xrepo_target_packages target)
    if(XREPO_PACKAGE_DISABLE)
        return()
    endif()

    foreach(package_name IN LISTS ARGN)
        if(DEFINED ${package_name}_INCLUDE_DIR)
            message(STATUS "xrepo: target_include_directories(${target} PRIVATE ${${package_name}_INCLUDE_DIR})")
            target_include_directories(${target} PRIVATE ${${package_name}_INCLUDE_DIR})
        endif()
        if(DEFINED ${package_name}_LINK_DIR)
            message(STATUS "xrepo: target_link_directories(${target} PRIVATE ${${package_name}_LINK_DIR})")
            target_link_directories(${target} PRIVATE ${${package_name}_LINK_DIR})
        endif()
        if(DEFINED ${package_name}_LINK_LIBRARIES)
            message(STATUS "xrepo: target_link_libraries(${target} PRIVATE ${${package_name}_LINK_LIBRARIES})")
            target_link_libraries(${target} PRIVATE ${${package_name}_LINK_LIBRARIES})
        endif()
    endforeach()
endfunction()

function(_xrepo_directory_scope package_name)
    if(DEFINED ${package_name}_INCLUDE_DIR)
        message(STATUS "xrepo: directory scope include_directories(${${package_name}_INCLUDE_DIR})")
        include_directories(${${package_name}_INCLUDE_DIR})
    endif()
    if(DEFINED ${package_name}_LINK_DIR)
        message(STATUS "xrepo: directory scope link_directories(${${package_name}_LINK_DIR})")
        link_directories(${${package_name}_LINK_DIR})
    endif()
endfunction()

function(_validate_mode mode)
    string(TOLOWER ${mode} _mode)
    if(NOT ((_mode STREQUAL "debug") OR (_mode STREQUAL "release")))
        message(FATAL_ERROR "xrepo_package invalid MODE: ${mode}, valid values: debug, release")
    endif()
endfunction()

function(_xrepo_package_name package)
    # For find_package(pkg) to work, we need to set variable <pkg>_DIR to the
    # cmake module directory provided by the package. Thus we need to extract
    # package name from package specification, which may also contain package
    # source and version.
    if(package MATCHES "^conan::.*")
        string(REGEX REPLACE "conan::([^/]+).*" "\\1" package_name ${package})
    elseif(package MATCHES "^conda::.*")
        string(REGEX REPLACE "conda::([^ ]+).*" "\\1" package_name ${package})
    elseif(package MATCHES "^vcpkg::.*")
        string(REGEX REPLACE "vcpkg::(.*)" "\\1" package_name ${package})
    elseif(package MATCHES "^brew::.*")
        string(REGEX REPLACE "brew::([^/]+).*" "\\1" package_name ${package})
    else()
        string(REGEX REPLACE "([^ ]+).*" "\\1" package_name ${package})
    endif()

    set(package_name ${package_name} PARENT_SCOPE)
endfunction()

macro(_xrepo_fetch_json)
    execute_process(COMMAND ${XREPO_CMD} fetch --json ${mode} ${platform} ${arch} ${toolchain} ${includes} ${configs} ${package}
                    OUTPUT_VARIABLE json_output
                    RESULT_VARIABLE exit_code)
    if(NOT "${exit_code}" STREQUAL "0")
        message(FATAL_ERROR "xrepo fetch --json failed, exit code: ${exit_code}")
    endif()

    # Loop over out most array for the json object.
    # The following code supports parsing the output of `xrepo fetch --deps`.
    # But pulling in the output of `--deps` is problematic because the dependent
    # libraries maybe using different configs.
    # For example, glog depends on gflags. But the gflags library pulled in by glog is with
    # default configs {mt=false,shared=false}, while the user maybe requiring gflags with
    # configs {mt=true,shared=true}.
    # It's error-prone so we don't support it for now.
    #message(STATUS "xrepo DEBUG: json output: ${json_output}")
    string(JSON len LENGTH ${json_output})
    math(EXPR len_end "${len} - 1")
    foreach(idx RANGE 0 ${len_end})
        # Loop over includedirs.
        string(JSON includedirs_len ERROR_VARIABLE includedirs_error LENGTH ${json_output} ${idx} includedirs)
        if("${includedirs_error}" STREQUAL "NOTFOUND")
            math(EXPR includedirs_end "${includedirs_len} - 1")
            foreach(includedirs_idx RANGE 0 ${includedirs_end})
                string(JSON dir GET ${json_output} ${idx} includedirs ${includedirs_idx})
                # It's difficult to know package name while looping over all packages.
                # Thus we use list to collect all include and link dirs.
                list(APPEND includedirs ${dir})
                #message(STATUS "xrepo DEBUG: includedirs ${idx} ${includedirs_idx} ${dir}")
            endforeach()
        endif()

        # Loop over linkdirs.
        string(JSON linkdirs_len ERROR_VARIABLE linkdirs_error LENGTH ${json_output} ${idx} linkdirs)
        if("${linkdirs_error}" STREQUAL "NOTFOUND")
            math(EXPR linkdirs_end "${linkdirs_len} - 1")
            foreach(linkdirs_idx RANGE 0 ${linkdirs_end})
                string(JSON dir GET ${json_output} ${idx} linkdirs ${linkdirs_idx})
                list(APPEND linkdirs ${dir})
                #message(STATUS "xrepo DEBUG: linkdirs ${idx} ${linkdirs_idx} ${dir}")

                if(IS_DIRECTORY "${dir}/cmake")
                    file(GLOB cmake_dirs LIST_DIRECTORIES true "${dir}/cmake/*")
                    foreach(cmakedir ${cmake_dirs})
                        get_filename_component(pkg "${cmakedir}" NAME)
                        set(${pkg}_DIR "${cmakedir}" CACHE INTERNAL "")
                        list(APPEND xrepo_vars_${package_name} ${pkg}_DIR)
                        message(STATUS "xrepo: ${pkg}_DIR ${${pkg}_DIR}")
                    endforeach()
                endif()
            endforeach()
        endif()

        # Loop over links.
        string(JSON links_len ERROR_VARIABLE links_error LENGTH ${json_output} ${idx} links)
        if("${links_error}" STREQUAL "NOTFOUND")
            math(EXPR links_end "${links_len} - 1")
            foreach(links_idx RANGE 0 ${links_end})
                string(JSON dir GET ${json_output} ${idx} links ${links_idx})
                list(APPEND links ${dir})
                #message(STATUS "xrepo DEBUG: links ${idx} ${links_idx} ${dir}")
            endforeach()
        endif()
    endforeach()

    if(DEFINED includedirs)
        set(${package_name}_INCLUDE_DIR "${includedirs}" CACHE INTERNAL "")
        list(APPEND xrepo_vars_${package_name} ${package_name}_INCLUDE_DIR)
        message(STATUS "xrepo: ${package_name}_INCLUDE_DIR ${${package_name}_INCLUDE_DIR}")
    else()
        message(STATUS "xrepo fetch --json: ${package_name} includedirs not found")
    endif()

    if(DEFINED linkdirs)
        set(${package_name}_LINK_DIR "${linkdirs}" CACHE INTERNAL "")
        list(APPEND xrepo_vars_${package_name} ${package_name}_LINK_DIR)
        message(STATUS "xrepo: ${package_name}_LINK_DIR ${${package_name}_LINK_DIR}")
    else()
        message(STATUS "xrepo fetch --json: ${package_name} linkdirs not found")
    endif()

    if(DEFINED links)
        set(${package_name}_LINK_LIBRARIES "${links}" CACHE INTERNAL "")
        list(APPEND xrepo_vars_${package_name} ${package_name}_LINK_LIBRARIES)
        message(STATUS "xrepo: ${package_name}_LINK_LIBRARIES ${${package_name}_LINK_LIBRARIES}")
    else()
        message(STATUS "xrepo fetch --json: ${package_name} links not found")
    endif()

    set(_cache_xrepo_vars_${package_name} "${xrepo_vars_${package_name}}" CACHE INTERNAL "")
endmacro()

macro(_xrepo_fetch_cflags)
    # Use cflags to get include path. Then we look for lib and cmake dir relative to include path.
    execute_process(COMMAND ${XREPO_CMD} fetch --cflags ${platform} ${arch} ${toolchain} ${includes} ${mode} ${configs} ${package}
                    OUTPUT_VARIABLE cflags_output
                    RESULT_VARIABLE exit_code)
    if(NOT "${exit_code}" STREQUAL "0")
        message(FATAL_ERROR "xrepo fetch --cflags failed, exit code: ${exit_code}")
    endif()

    string(REGEX REPLACE "-I(.*)/include.*" "\\1" install_dir ${cflags_output})

    set(${package_name}_INCLUDE_DIR "${install_dir}/include" CACHE INTERNAL "")
    list(APPEND xrepo_vars_${package_name} ${package_name}_INCLUDE_DIR)
    message(STATUS "xrepo: ${package_name}_INCLUDE_DIR ${${package_name}_INCLUDE_DIR}")

    if(EXISTS "${install_dir}/lib")
        set(${package_name}_LINK_DIR "${install_dir}/lib" CACHE INTERNAL "")
        list(APPEND xrepo_vars_${package_name} ${package_name}_LINK_DIR)
        message(STATUS "xrepo: ${package_name}_LINK_DIR ${${package_name}_LINK_DIR}")
    endif()
    if(EXISTS "${install_dir}/lib/cmake/${package_name}")
        set(${package_name}_DIR "${install_dir}/lib/cmake/${package_name}" CACHE INTERNAL "")
        list(APPEND xrepo_vars_${package_name} ${package_name}_DIR)
        message(STATUS "xrepo: ${package_name}_DIR ${${package_name}_DIR}")
    endif()

    set(_cache_xrepo_vars_${package_name} "${xrepo_vars_${package_name}}" CACHE INTERNAL "")
endmacro()
