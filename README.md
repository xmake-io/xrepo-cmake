# xrepo-cmake

CMake wrapper for [Xrepo](https://xrepo.xmake.io/) C and C++ package manager.

This allows using CMake to build your project, while using Xrepo to manage
dependent packages. This project is partially inspired by
[cmake-conan](https://github.com/conan-io/cmake-conan).

Example use cases for this project:

- Existing CMake projects which want to use Xrepo to manage packages.
- New projects which have to use CMake, but want to use Xrepo to manage
  packages.

# Usage

[`xrepo.cmake`](./xrepo.cmake) provides `xrepo_package` function to manage
packages.

```cmake
xrepo_package(
    "foo 1.2.3"
    [CONFIGS feature1=true,feature2=false]
    [MODE debug|release]
    [DIRECTORY_SCOPE]
)
```

Some of the function arguments correspond directly to Xrepo command options.

After calling `xrepo_package(foo)`, there are two ways to use `foo` package:

- Call `find_package(foo)` if package provides cmake modules to find it
  - Refer to CMake [`find_package`](https://cmake.org/cmake/help/latest/command/find_package.html) documentation for more details
- If the package does not provide cmake modules, `foo_INCLUDE_DIR` and
  `foo_LINK_DIR` variables will be set to the package include and library paths.
  Use these variables to setup include and library paths in your CMake code.
  - If `DIRECTORY_SCOPE` is specified, `xrepo_package` will run following code
    (so that user only need to specify lib name in `target_link_libraries`)
  ```cmake
    include_directories(foo_INCLUDE_DIR)
    link_directories(foo_LINK_DIR)
  ```

Here's an example `CMakeLists.txt` that uses `gflags` package version 2.2.2
managed by Xrepo.

```cmake
cmake_minimum_required(VERSION 3.13.0)

project(foo)

# Download xrepo.cmake if not exists in build directory.
if(NOT EXISTS "${CMAKE_BINARY_DIR}/xrepo.cmake")
    message(STATUS "Downloading xrepo.cmake from https://github.com/xmake-io/xrepo-cmake/")
    file(DOWNLOAD "https://raw.githubusercontent.com/xmake-io/xrepo-cmake/main/xrepo.cmake"
                  "${CMAKE_BINARY_DIR}/xrepo.cmake"
                  TLS_VERIFY ON)
endif()

# Include xrepo.cmake so we can use xrepo_package function.
include(${CMAKE_BINARY_DIR}/xrepo.cmake)

# Call `xrepo_package` function to use gflags 2.2.2 with specific configs.
xrepo_package("gflags 2.2.2" CONFIGS "shared=true,mt=true")

# `xrepo_package` sets `gflags_DIR` variable in parent scope because gflags
# provides cmake modules. So we can now call `find_package` to find gflags
# package.
find_package(gflags CONFIG COMPONENTS shared)
```

# How does it work?

[`xrepo.cmake`](./xrepo.cmake) module basically does the following tasks:

- Call `xrepo install` to ensure specific package is installed.
- Call `xrepo fetch` to get package information and setup various variables for
  using the installed package in CMake.

The following section is a short introduction to using Xrepo. It helps to
understand how `xrepo.cmake` works and how to specify some of the options in
`xrepo_package`.

## Xrepo workflow

Assume [Xmake](https://github.com/xmake-io/xmake/) is installed.

Suppose we want to use `gflags` packages.

First, search for `gflags` package in Xrepo.

```
$ xrepo search gflags
The package names:
    gflags:
      -> gflags-v2.2.2: The gflags package contains a C++ library that implements commandline flags processing. (in builtin-repo)
```

It's already in Xrepo, so we can use it. If it's not in Xrepo, we can create it in
[self-built repositories](https://xrepo.xmake.io/#/getting_started?id=suppory-distributed-repository).

Let's see what configs are available for the package before using it:

```
$ xrepo info gflags
...
      -> configs:
         -> mt: Build the multi-threaded gflags library. (default: false)
      -> configs (builtin):
         -> debug: Enable debug symbols. (default: false)
         -> shared: Build shared library. (default: false)
         -> pic: Enable the position independent code. (default: true)
...
```

Suppose we want to use multi-threaded gflags shared library. We can install the package with following command:

```
xrepo install --mode=release --configs='mt=true,shared=true' 'gflags 2.2.2'
```

Only the first call to the above command will compile and install the package. So `xrepo_package` always calls the above command to ensure the package is installed.

After package installation, because we are using CMake instead of Xmake, we have
to get package installation information by ourself. `xrepo fetch` command does
exactly this:

```
xrepo fetch --mode=release --configs='mt=true,shared=true' 'gflags 2.2.2'
```

The above command will print out package's include, library directory along with
other information. `xrepo_package` uses these information to setup variables to use
the specified package.

Currently, `xrepo_package` uses only the `--cflags` option to get package
include directory. Library and cmake module directory are infered from that
directory, so it maybe unreliable to detect the correct paths. We will improve
this in the future.
