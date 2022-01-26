<div align="center">
  <a href="https://xrepo.xmake.io">
    <img width="160" heigth="160" src="https://tboox.org/static/img/xmake/logo256c.png">
  </a>

  <h1>xrepo-cmake</h1>

  <div>
    <a href="https://github.com/xmake-io/xrepo-cmake/actions?query=workflow%3AWindows">
      <img src="https://img.shields.io/github/workflow/status/xmake-io/xrepo-cmake/Windows/main.svg?style=flat-square&logo=windows" alt="github-ci" />
    </a>
    <a href="https://github.com/xmake-io/xrepo-cmake/actions?query=workflow%3ALinux">
      <img src="https://img.shields.io/github/workflow/status/xmake-io/xrepo-cmake/Linux/main.svg?style=flat-square&logo=linux" alt="github-ci" />
    </a>
    <a href="https://github.com/xmake-io/xrepo-cmake/actions?query=workflow%3AmacOS">
      <img src="https://img.shields.io/github/workflow/status/xmake-io/xrepo-cmake/macOS/main.svg?style=flat-square&logo=apple" alt="github-ci" />
    </a>
  </div>
  <div>
    <a href="https://github.com/xmake-io/xmake/blob/main/LICENSE.md">
      <img src="https://img.shields.io/github/license/xmake-io/xmake.svg?colorB=f48041&style=flat-square" alt="license" />
    </a>
    <a href="https://www.reddit.com/r/xmake/">
      <img src="https://img.shields.io/badge/chat-on%20reddit-ff3f34.svg?style=flat-square" alt="Reddit" />
    </a>
    <a href="https://gitter.im/xmake-io/xmake?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge">
      <img src="https://img.shields.io/gitter/room/xmake-io/xmake.svg?style=flat-square&colorB=96c312" alt="Gitter" />
    </a>
    <a href="https://t.me/tbooxorg">
      <img src="https://img.shields.io/badge/chat-on%20telegram-blue.svg?style=flat-square" alt="Telegram" />
    </a>
    <a href="https://jq.qq.com/?_wv=1027&k=5hpwWFv">
      <img src="https://img.shields.io/badge/chat-on%20QQ-ff69b4.svg?style=flat-square" alt="QQ" />
    </a>
    <a href="https://discord.gg/xmake">
      <img src="https://img.shields.io/badge/chat-on%20discord-7289da.svg?style=flat-square" alt="Discord" />
    </a>
    <a href="https://xmake.io/#/sponsor">
      <img src="https://img.shields.io/badge/donate-us-orange.svg?style=flat-square" alt="Donate" />
    </a>
  </div>

  <b>CMake wrapper for Xrepo C and C++ package manager.</b><br/>
</div>

## Supporting the project

Support this project by [becoming a sponsor](https://xmake.io/#/about/sponsor). Your logo will show up here with a link to your website. 🙏

<a href="https://opencollective.com/xmake#sponsors" target="_blank"><img src="https://opencollective.com/xmake/sponsors.svg?width=890"></a>
<a href="https://opencollective.com/xmake#backers" target="_blank"><img src="https://opencollective.com/xmake/backers.svg?width=890"></a>

## Introduction

CMake wrapper for [Xrepo](https://xrepo.xmake.io/) C and C++ package manager.

This allows using CMake to build your project, while using Xrepo to manage
dependent packages. This project is partially inspired by
[cmake-conan](https://github.com/conan-io/cmake-conan).

Example use cases for this project:

- Existing CMake projects which want to use Xrepo to manage packages.
- New projects which have to use CMake, but want to use Xrepo to manage
  packages.

## Usage

### Apis

#### xrepo_package

[`xrepo.cmake`](./xrepo.cmake) provides `xrepo_package` function to manage
packages.

```cmake
xrepo_package(
    "foo 1.2.3"
    [CONFIGS feature1=true,feature2=false]
    [MODE debug|release]
    [ALIAS aliasname]
    [OUTPUT verbose|diagnosis|quiet]
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
    include_directories(${foo_INCLUDE_DIR})
    link_directories(${foo_LINK_DIR})
  ```

#### xrepo_target_packages

Add package includedirs and links/linkdirs to the given target.

```cmake
xrepo_target_packages(
    target
    package1 package2 ...
)
```

### Use package from official repository

Xrepo official repository: [xmake-repo](https://github.com/xmake-io/xmake-repo)

Here's an example `CMakeLists.txt` that uses `gflags` package version 2.2.2
managed by Xrepo.

#### Integrate xrepo.cmake

```cmake
cmake_minimum_required(VERSION 3.13.0)

project(foo)

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
```

#### Add basic packages

```cmake
xrepo_package("zlib")

add_executable(example-bin "")
target_sources(example-bin PRIVATE
    src/main.cpp
)
xrepo_target_packages(example-bin zlib)
```

#### Add packages with configs

```cmake
xrepo_package("gflags 2.2.2" CONFIGS "shared=true,mt=true")

add_executable(example-bin "")
target_sources(example-bin PRIVATE
    src/main.cpp
)
xrepo_target_packages(example-bin gflags)
```

#### Add packages with cmake modules

```cmake
xrepo_package("gflags 2.2.2" CONFIGS "shared=true,mt=true")

# `xrepo_package` sets `gflags_DIR` variable in parent scope because gflags
# provides cmake modules. So we can now call `find_package` to find gflags
# package.
find_package(gflags CONFIG COMPONENTS shared)

add_executable(example-bin "")
target_sources(example-bin PRIVATE
    src/main.cpp
)
target_link_libraries(example-bin gflags)
```

#### Add custom packages

We can also add custom packages in our project.

```cmake
set(XREPO_XMAKEFILE ${CMAKE_CURRENT_SOURCE_DIR}/packages/xmake.lua)
xrepo_package("myzlib")

add_executable(example-bin "")
target_sources(example-bin PRIVATE
    src/main.cpp
)
xrepo_target_packages(example-bin myzlib)
```

Define myzlib package in packages/xmake.lua

```lua
package("myzlib")
    set_homepage("http://www.zlib.net")
    set_description("A Massively Spiffy Yet Delicately Unobtrusive Compression Library")

    set_urls("http://zlib.net/zlib-$(version).tar.gz",
             "https://downloads.sourceforge.net/project/libpng/zlib/$(version)/zlib-$(version).tar.gz")

    add_versions("1.2.10", "8d7e9f698ce48787b6e1c67e6bff79e487303e66077e25cb9784ac8835978017")

    on_install(function (package)
		-- TODO
    end)

    on_test(function (package)
        assert(package:has_cfuncs("inflate", {includes = "zlib.h"}))
    end)
```

We can write a custom package in xmake.lua, please refer [Define Xrepo package](https://xmake.io/#/package/remote_package?id=package-description).

### Options and variables for `xrepo.cmake`

Following options can be speicified with `cmake -D<var>=<value>`.
Or use `set(var value)` in `CMakeLists.txt`.

- `XMAKE_CMD`: string, defaults to empty string
  - Specify path to `xmake` command. Use this option if `xmake` is not installed
    in standard location and can't be detected automatically.
- `XREPO_PACKAGE_VERBOSE`: `[ON|OFF]`
  - Enable verbose output for Xrepo Packages.
- `XREPO_BOOTSTRAP_XMAKE`: `[ON|OFF]`
  - If `ON`, `xrepo.cmake` will install `xmake` if it is not found.
- `XREPO_PACKAGE_DISABLE`: `[ON|OFF]`
  - Set this to `ON` to disable `xrepo_package` function.
  - If setting this variable in `CMakeLists.txt`, please set it before including
    `xrepo.cmake`.

### Switching compiler and cross compilation

Following variables controll cross compilation. Note: to specify a different compiler other than
the default one on system, platform must be set to "cross".

- `XREPO_TOOLCHAIN`: string, defaults to empty string
  - Specify toolchain name. Run `xmake show -l toolchains` to see available toolchains.
- `XREPO_PLATFORM`: string, defaults to empty string
  - Specify platform name. If `XREPO_TOOLCHAIN` is specified and this is not,
    `XREPO_PLATFORM` will be set to `cross`.
- `XREPO_ARCH`: string, defaults to empty string
  - Specify architecture name.
- `XREPO_XMAKEFILE`: string, defaults to empty string
  - Specify Xmake script file of Xrepo package.

### Use package from 3rd repository

In addition to installing packages from officially maintained repository,
Xrepo can also install packages from third-party package managers such as vcpkg/conan/conda/pacman/homebrew/apt/dub/cargo.

For the use of the command line, we can refer to the documentation: [Xrepo command usage](https://xrepo.xmake.io/#/getting_started?id=install-packages-from-third-party-package-manager)

We can also use it directly in cmake to install packages from third-party repositories, just add the repository name as a namespace. e.g. `vcpkg::zlib`, `conan::pcre2`

#### Conan

```cmake
xrepo_package("conan::gflags/2.2.2")
```

#### Conda

```cmake
xrepo_package("conda::gflags 2.2.2")
```

#### Vcpkg

```cmake
xrepo_package("vcpkg::gflags")
```

#### Homebrew

```cmake
xrepo_package("brew::gflags")
```

## How does it work?

[`xrepo.cmake`](./xrepo.cmake) module basically does the following tasks:

- Call `xrepo install` to ensure specific package is installed.
- Call `xrepo fetch` to get package information and setup various variables for
  using the installed package in CMake.

The following section is a short introduction to using Xrepo. It helps to
understand how `xrepo.cmake` works and how to specify some of the options in
`xrepo_package`.

### Xrepo workflow

Assmuing [Xmake](https://github.com/xmake-io/xmake/) is installed.

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

Only the first call to the above command will compile and install the package.
To speed up cmake configuration, `xrepo` command will only be executed when the
package is not installed or `xrepo_package` parameters have changed.

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
