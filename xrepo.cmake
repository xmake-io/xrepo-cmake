# xrepo_package:
#
# Parameters:
#     package_spec: required
#         The package name and version recognized by xrepo.
#     CONFIGS: optional
#         Run `xrepo info <package>` to see what configs are available.
#     MODE: optional
#         If not specified: mode is set to "debug" only when $CMAKE_BUILD_TYPE
#         is Debug. Otherwise mode is `release`.
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
# 3. If package provides cmake modules under `foo_LINK_DIR/cmake/package`,
#    set `foo_DIR` to the module directory so that `find_package(foo)`
#    can be used.
function(xrepo_package package)
    find_program(xrepo_cmd xrepo)
    if(NOT xrepo_cmd)
        message(FATAL_ERROR "xrepo executable not found!")
    endif()

    set(options DIRECTORY_SCOPE)
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
        string(TOLOWER ${CMAKE_BUILD_TYPE} _cmake_build_type)
        if(_cmake_build_type STREQUAL "debug")
            set(mode "--mode=debug")
        else()
            set(mode "--mode=release")
        endif()
    endif()

    message(STATUS "xrepo install ${mode} ${configs} ${package}")
    execute_process(COMMAND ${xrepo_cmd} install --yes --quiet ${mode} ${configs} ${package}
                    RESULT_VARIABLE exit_code)
    if(NOT "${exit_code}" STREQUAL "0")
        message(FATAL_ERROR "xrepo install failed, exit code: ${exit_code}")
    endif()

    # Set up variables to use package.
    # Use cflags to get path to headers. Then we look for lib dir based on headers dir.
    # TODO Find more reliable way to setup for using a package. Maybe change
    # xrepo to support generating cmake find package related code.
    execute_process(COMMAND ${xrepo_cmd} fetch --cflags ${mode} ${configs} ${package}
                    OUTPUT_VARIABLE cflags_output
                    RESULT_VARIABLE exit_code)
    if(NOT "${exit_code}" STREQUAL "0")
        message(FATAL_ERROR "xrepo fetch failed, exit code: ${exit_code}")
    endif()

    string(REGEX REPLACE "-I(.*)/include.*" "\\1" install_dir ${cflags_output})
    string(REGEX REPLACE "([^ ]+).*" "\\1" package_name ${package})
    message(STATUS "xrepo ${package_name} install_dir: ${install_dir}")

    set(${package_name}_INCLUDE_DIR ${install_dir}/include PARENT_SCOPE)

    if(EXISTS ${install_dir}/lib)
        set(${package_name}_LINK_DIR ${install_dir}/lib PARENT_SCOPE)
    endif()
    if(EXISTS ${install_dir}/lib/cmake/${package_name})
        set(${package_name}_DIR ${install_dir}/lib/cmake/${package_name} PARENT_SCOPE)
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

