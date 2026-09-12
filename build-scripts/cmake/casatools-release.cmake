# -*- mode: cmake -*-
# CMake toolchain hook for casatools Release build & binary stripping
# Automatically loaded by CMake via CMAKE_TOOLCHAIN_FILE environment variable

# Enforce standard Release build type (-O3 -DNDEBUG, no -g)
set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Choose the type of build." FORCE)

# On Linux, instruct linker to omit DWARF debug tables from shared libraries
if(NOT APPLE)
  set(CMAKE_SHARED_LINKER_FLAGS_INIT "-Wl,--strip-debug")
endif()
