cmake_minimum_required(VERSION 3.16)
project(rime_regsp_preedit LANGUAGES CXX)

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# regsp_preedit_decode.cc builds its 3925-row syllable table at compile time,
# which needs more constant-evaluation steps than clang's default of 1048576
# (measured: ~1.50M with clang 19, ~0.43M when the tables compared C strings
# instead of string_views).  Raise the limit for that one file; it is a guard
# against runaway evaluation, not a language limit, so the value only has to
# leave room for the table to grow.  GCC's knob (-fconstexpr-ops-limit) already
# defaults to a value that is high enough.
if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  set_source_files_properties(src/regsp_preedit_decode.cc
    PROPERTIES COMPILE_OPTIONS "-fconstexpr-steps=4194304")
endif()

# In-tree: librime's plugins/CMakeLists.txt add_subdirectory()s this project
# and wraps plugin_objs into librime-regsp-preedit.dylib, which Squirrel ships
# as Contents/Frameworks/rime-plugins/librime-regsp-preedit.dylib. Standalone:
# build and install the same dylib against an installed librime plus a librime
# source checkout (its internal headers are not installed).
if(DEFINED rime_library)
  add_library(rime-regsp-preedit-objs OBJECT
    src/regsp_preedit_decode.cc
    src/regsp_preedit_filter.cc)
  if(BUILD_SHARED_LIBS)
    set_target_properties(rime-regsp-preedit-objs
      PROPERTIES POSITION_INDEPENDENT_CODE ON)
  endif()
  set(plugin_name "rime-regsp-preedit" PARENT_SCOPE)
  set(plugin_objs $<TARGET_OBJECTS:rime-regsp-preedit-objs> PARENT_SCOPE)
  set(plugin_deps ${rime_library} ${rime_gears_library} PARENT_SCOPE)
  set(plugin_modules "" PARENT_SCOPE)
else()
  if(DEFINED ENV{LIBRIME_SOURCE_DIR})
    set(LIBRIME_SOURCE_DIR "$ENV{LIBRIME_SOURCE_DIR}" CACHE PATH "librime source checkout")
  else()
    set(LIBRIME_SOURCE_DIR "" CACHE PATH "librime source checkout")
  endif()

  find_package(PkgConfig REQUIRED)
  pkg_check_modules(RIME REQUIRED IMPORTED_TARGET rime)

  if(NOT LIBRIME_SOURCE_DIR)
    message(FATAL_ERROR "LIBRIME_SOURCE_DIR is required for librime internal C++ headers")
  endif()

  # librime's headers #include <rime/build_config.h> unconditionally, and
  # librime generates that header at configure time instead of installing it.
  # Generate one from the same template, so a standalone build sees the
  # configuration librime itself was built with (ENABLE_LOGGING defaults to ON
  # and needs glog, which librime links against).
  set(RIME_ENABLE_LOGGING 1)
  configure_file(
    "${LIBRIME_SOURCE_DIR}/src/rime/build_config.h.in"
    "${CMAKE_CURRENT_BINARY_DIR}/include/rime/build_config.h")

  add_library(rime-regsp-preedit SHARED
    src/regsp_preedit_decode.cc
    src/regsp_preedit_filter.cc)

  target_include_directories(rime-regsp-preedit PRIVATE
    "${CMAKE_CURRENT_BINARY_DIR}/include"
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
    "${LIBRIME_SOURCE_DIR}/src"
  )

  target_compile_definitions(rime-regsp-preedit PRIVATE
    GLOG_USE_GLOG_EXPORT
  )

  target_link_libraries(rime-regsp-preedit PRIVATE
    PkgConfig::RIME
  )

  set_target_properties(rime-regsp-preedit PROPERTIES
    OUTPUT_NAME "rime-regsp-preedit"
  )

  install(TARGETS rime-regsp-preedit
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}/rime-plugins"
  )

  # Development helper.
  option(REGSP_PREEDIT_BUILD_TESTS "Build the standalone decoder test" OFF)
  if(REGSP_PREEDIT_BUILD_TESTS)
    add_executable(decode_test
      test/decode_test.cc
      src/regsp_preedit_decode.cc)
    target_include_directories(decode_test PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src")
  endif()
endif()
