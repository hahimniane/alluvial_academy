# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "flutter_zoom_meeting_sdk")
project(${PROJECT_NAME} LANGUAGES CXX)

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "flutter_zoom_meeting_sdk_plugin")

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "flutter_zoom_meeting_sdk_plugin.cpp"
  "flutter_zoom_meeting_sdk_plugin.h"
  "zoom_event_stream_handler.h"
  "zoom_event_manager.h"
  "zoom_event_manager.cpp"
  "zoom_event_listener_base.h"
  "zoom_event_listener_base.cpp"
  "zoom_event_listener_auth_service.h"
  "zoom_event_listener_auth_service.cpp"
  "zoom_event_listener_meeting_service.h"
  "zoom_event_listener_meeting_service.cpp"
  "zoom_response.h"
  "zoom_response_builder.h"
  "zoom_response_builder.cpp"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "include/flutter_zoom_meeting_sdk/flutter_zoom_meeting_sdk_plugin_c_api.h"
  "flutter_zoom_meeting_sdk_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

# === Zoom SDK Configuration based on Visual Studio settings ===

# Set the path to the Zoom SDK installation
# First check if ZOOM_SDK_PATH environment variable is set
if(DEFINED ENV{ZOOM_SDK_PATH})
  set(ZOOM_SDK_DIR $ENV{ZOOM_SDK_PATH})
  message(STATUS "Using Zoom SDK from environment variable: ${ZOOM_SDK_DIR}")
else()
  # Check if a custom path was provided via -DZOOM_SDK_DIR=path/to/sdk
  if(NOT DEFINED ZOOM_SDK_DIR)
    # Default fallback path
    set(ZOOM_SDK_DIR "${CMAKE_CURRENT_SOURCE_DIR}/libs")
    message(STATUS "Using default Zoom SDK path: ${ZOOM_SDK_DIR}")
  else()
    message(STATUS "Using provided Zoom SDK path: ${ZOOM_SDK_DIR}")
  endif()
endif()

# Verify the SDK directory exists
if(NOT EXISTS "${ZOOM_SDK_DIR}")
  message(WARNING "Zoom SDK directory not found at ${ZOOM_SDK_DIR}. Build may fail.")
endif()

# Include directories
include_directories(
  "${ZOOM_SDK_DIR}/h"
)

# VC++ Directories > Include Directories
# C/C++ > General > Additional Include Directories
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${ZOOM_SDK_DIR}/h")

# VC++ Directories > Library Directories
# Linker > General > Additional Library Directories
link_directories("${ZOOM_SDK_DIR}/lib")

# Linker > Input > Additional Dependencies
target_link_libraries(${PLUGIN_NAME} PRIVATE
  "${ZOOM_SDK_DIR}/lib/sdk.lib")

# Copy Zoom SDK DLLs to output directory
add_custom_command(TARGET ${PLUGIN_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_directory
    "${ZOOM_SDK_DIR}/bin"
    "$<TARGET_FILE_DIR:${PLUGIN_NAME}>"
)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(flutter_zoom_meeting_sdk_bundled_libraries
  ""
  PARENT_SCOPE
)

# === Tests ===
# These unit tests can be run from a terminal after building the example, or
# from Visual Studio after opening the generated solution file.

# Only enable test builds when building the example (which sets this variable)
# so that plugin clients aren't building the tests.
if (${include_${PROJECT_NAME}_tests})
set(TEST_RUNNER "${PROJECT_NAME}_test")
enable_testing()

# Add the Google Test dependency.
include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/release-1.11.0.zip
)
# Prevent overriding the parent project's compiler/linker settings
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
# Disable install commands for gtest so it doesn't end up in the bundle.
set(INSTALL_GTEST OFF CACHE BOOL "Disable installation of googletest" FORCE)
FetchContent_MakeAvailable(googletest)

# The plugin's C API is not very useful for unit testing, so build the sources
# directly into the test binary rather than using the DLL.
add_executable(${TEST_RUNNER}
  test/flutter_zoom_meeting_sdk_plugin_test.cpp
  ${PLUGIN_SOURCES}
)
apply_standard_settings(${TEST_RUNNER})
target_include_directories(${TEST_RUNNER} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")

# Add Zoom SDK configuration for test target
target_include_directories(${TEST_RUNNER} PRIVATE "${ZOOM_SDK_DIR}/h")
target_link_libraries(${TEST_RUNNER} PRIVATE "${ZOOM_SDK_DIR}/lib/sdk.lib")

target_link_libraries(${TEST_RUNNER} PRIVATE flutter_wrapper_plugin)
target_link_libraries(${TEST_RUNNER} PRIVATE gtest_main gmock)

# Copy Zoom SDK DLLs to test output directory
add_custom_command(TARGET ${TEST_RUNNER} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_directory
    "${ZOOM_SDK_DIR}/bin"
    "$<TARGET_FILE_DIR:${TEST_RUNNER}>"
)

# flutter_wrapper_plugin has link dependencies on the Flutter DLL.
add_custom_command(TARGET ${TEST_RUNNER} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
  "${FLUTTER_LIBRARY}" $<TARGET_FILE_DIR:${TEST_RUNNER}>
)

# Enable automatic test discovery.
include(GoogleTest)
gtest_discover_tests(${TEST_RUNNER})
endif()
