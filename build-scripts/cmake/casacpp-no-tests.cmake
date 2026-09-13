# -*- mode: cmake -*-
# CMake project injection hook for casacpp
# Loaded via -DCMAKE_PROJECT_casacpp_INCLUDE when configuring casacpp

if(NOT BUILD_TESTING)
  message(STATUS "casacpp: BUILD_TESTING is OFF -> test executables will be excluded from default 'ALL' build target")
  # Override add_executable to add EXCLUDE_FROM_ALL to local executables (e.g. test binaries)
  # while leaving IMPORTED or ALIAS targets (e.g. protobuf::protoc, gRPC::grpc_cpp_plugin) untouched.
  macro(add_executable _name)
    if(";${ARGN};" MATCHES ";(IMPORTED|ALIAS);")
      _add_executable(${_name} ${ARGN})
    else()
      _add_executable(${_name} EXCLUDE_FROM_ALL ${ARGN})
    endif()
  endmacro()
endif()
