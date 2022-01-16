# xrepo_package:
#
# Parameters:
#     package_spec: required
#         The package name and version recognized by xrepo.
#     CONFIGS: optional
#         Run `xrepo info <package>` to see what configs are available.
#     MODE: optional, debug|release
#         If not specified: mode is set to "debug" only when $CMAKE_BUILD_TYPE
#         is Debug. Otherwise mode is `release`.
#     OUTPUT: optional, verbose|diagnosis|quiet
#         Control output for xrepo install command.
#     DIRECTORY_SCOPE: optional
#         If specified, setup include and link directories for the package in
#         CMake directory scope. CMake code in `add_subdirectory` can also use
#         the package directly.
#
# Example:
#
#     xrepo_package(
#         "foo 1.2.3"
#         [CONFIGS feature1=true,feature2=false]
#         [MODE debug|release]
#         [OUTPUT verbose|diagnosis|quiet]
#         [DIRECTORY_SCOPE]
#     )
#
# `xrepo_package` does the following tasks for the above call:
#
# 1. Ensure specified package `foo` version 1.2.3 with given config is installed.
# 2. Set variable `foo_INCLUDE_DIR` and `foo_LINK_DIR` to header and library
#    path.
#    -  Use these variables in `target_include_directories` and
#      `target_link_directories` to use the package.
#    - User should figure out what library to use for `target_link_libraries`.
#    - If `DIRECTORY_SCOPE` is specified, execute following code so the package
#      can be used in cmake's direcotry scope:
#          include_directories(foo_INCLUDE_DIR)
#          link_directories(foo_LINK_DIR)
# 3. If package provides cmake modules under `${foo_LINK_DIR}/cmake/foo`,
#    set `foo_DIR` to the module directory so that `find_package(foo)`
#    can be used.

option(XREPO_PACKAGE_DISABLE "Disable Xrepo Packages" OFF)

find_program(XMAKE_CMD xmake)
set(XREPO_CMD ${XMAKE_CMD} lua private.xrepo)

function(_xrepo_detect_json_support)
    if(XREPO_PACKAGE_DISABLE)
        return()
    endif()

    # Whether to use `xrepo fetch --json` to get package info.
    set(XREPO_FETCH_JSON ON)

    if(${CMAKE_VERSION} VERSION_LESS "3.19")
        message(WARNING "CMake version < 3.19 has no JSON support, xrepo_package maybe unreliable to setup package variables")
        set(XREPO_FETCH_JSON OFF)
    elseif(XREPO_CMD)
        # Detect if the installed xrepo supports fetch --json option.
        execute_process(COMMAND ${XREPO_CMD} fetch --json tbox
                        RESULT_VARIABLE exit_code)
        if(NOT "${exit_code}" STREQUAL "0")
            message(WARNING "xrepo fetch --json not supported, xrepo_package maybe unreliable to setup package variables")
            set(XREPO_FETCH_JSON OFF)
        endif()
    endif()

    message(STATUS "xrepo fetch --json support: ${XREPO_FETCH_JSON}")
    set(XREPO_FETCH_JSON ${XREPO_FETCH_JSON} PARENT_SCOPE)
endfunction()

_xrepo_detect_json_support()

function(xrepo_package package)
    if(XREPO_PACKAGE_DISABLE)
        return()
    endif()

    if(NOT XMAKE_CMD)
        message(FATAL_ERROR "xmake executable not found!")
    endif()

    set(options DIRECTORY_SCOPE)
    set(one_value_args CONFIGS MODE OUTPUT)
    cmake_parse_arguments(ARG "${options}" "${one_value_args}" "" ${ARGN})

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

    if(DEFINED ARG_OUTPUT)
        string(TOLOWER "${ARG_OUTPUT}" _output)
        if(_output STREQUAL "diagnosis")
            set(verbose "-vD")
        elseif(_output STREQUAL "verbose")
            set(verbose "-v")
        elseif(_output STREQUAL "quiet")
            set(verbose "-q")
        endif()
    endif()

    message(STATUS "xrepo install ${verbose} ${mode} ${configs} '${package}'")
    execute_process(COMMAND ${XREPO_CMD} install --yes ${verbose} ${mode} ${configs} ${package}
                    RESULT_VARIABLE exit_code)
    if(NOT "${exit_code}" STREQUAL "0")
        message(FATAL_ERROR "xrepo install failed, exit code: ${exit_code}")
    endif()

    # Set up variables to use package.
    string(REGEX REPLACE "([^ ]+).*" "\\1" package_name ${package})

    if(XREPO_FETCH_JSON)
        _xrepo_fetch_json()
    else()
        _xrepo_fetch_cflags()
    endif()

    if(_XREPO_DIRECTORY_SCOPE)
        message(STATUS "set ${package} include dir")
        include_directories(${${package_name}_INCLUDE_DIR})
        if(DEFINED ${package_name}_LINK_DIR)
            message(STATUS "set ${package} link dir")
            include_directories(${${package_name}_LINK_DIR})
        endif()
    endif()
endfunction()

function(_validate_mode mode)
    string(TOLOWER ${mode} _mode)
    if(NOT ((_mode STREQUAL "debug") OR (_mode STREQUAL "release")))
        message(FATAL_ERROR
            "xrepo_package invalid MODE: ${mode}, valid values: debug, release")
    endif()
endfunction()

macro(_xrepo_fetch_json)
    # Use cflags to get include path. Then we look for lib and cmake dir relative to include path.
    execute_process(COMMAND ${XREPO_CMD} fetch --json ${mode} ${configs} ${package}
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
                        set(${pkg}_DIR "${cmakedir}" PARENT_SCOPE)
                        message(STATUS "xrepo: ${pkg}_DIR ${idx} ${linkdirs_idx} ${cmakedir}")
                    endforeach()
                endif()
            endforeach()
        endif()
    endforeach()

    if(DEFINED includedirs)
        set(${package_name}_INCLUDE_DIR "${includedirs}" PARENT_SCOPE)
        message(STATUS "xrepo: ${package_name}_INCLUDE_DIR ${includedirs}")
    else()
        message(STATUS "xrepo fetch --json: ${package_name} includedirs not found")
    endif()

    if(DEFINED linkdirs)
        set(${package_name}_LINK_DIR "${linkdirs}" PARENT_SCOPE)
        message(STATUS "xrepo: ${package_name}_LINK_DIR ${linkdirs}")
    else()
        message(STATUS "xrepo fetch --json: ${package_name} linkdirs not found")
    endif()
endmacro()

macro(_xrepo_fetch_cflags)
    # Use cflags to get include path. Then we look for lib and cmake dir relative to include path.
    execute_process(COMMAND ${XREPO_CMD} fetch --cflags ${mode} ${configs} ${package}
                    OUTPUT_VARIABLE cflags_output
                    RESULT_VARIABLE exit_code)
    if(NOT "${exit_code}" STREQUAL "0")
        message(FATAL_ERROR "xrepo fetch --cflags failed, exit code: ${exit_code}")
    endif()

    string(REGEX REPLACE "-I(.*)/include.*" "\\1" install_dir ${cflags_output})

    set(${package_name}_INCLUDE_DIR "${install_dir}/include" PARENT_SCOPE)
    message(STATUS "${package_name}_INCLUDE_DIR: ${install_dir}/include")

    if(EXISTS "${install_dir}/lib")
        set(${package_name}_LINK_DIR "${install_dir}/lib" PARENT_SCOPE)
        message(STATUS "${package_name}_LINK_DIR: ${install_dir}/lib")
    endif()
    if(EXISTS "${install_dir}/lib/cmake/${package_name}")
        set(${package_name}_DIR "${install_dir}/lib/cmake/${package_name}" PARENT_SCOPE)
        message(STATUS "${package_name}_DIR: ${install_dir}/lib/cmake/${package_name}")
    endif()
endmacro()
