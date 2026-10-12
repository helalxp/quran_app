cmake_minimum_required(VERSION 3.14)
project(mushaf_renderer CXX)

include(FetchContent)

# Stop sub-projects from installing themselves
set(SKIP_INSTALL_ALL ON)
set(CMAKE_SKIP_INSTALL_ALL_DEPENDENCY ON)

# --- FreeType ---
message(STATUS "Fetching FreeType...")
FetchContent_Declare(
  freetype
  GIT_REPOSITORY https://gitlab.freedesktop.org/freetype/freetype.git
  GIT_TAG        VER-2-13-2
)
set(FT_DISABLE_ZLIB ON CACHE BOOL "" FORCE)
set(FT_DISABLE_BZIP2 ON CACHE BOOL "" FORCE)
set(FT_DISABLE_PNG ON CACHE BOOL "" FORCE)
set(FT_DISABLE_BROTLI ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(freetype)

# --- HarfBuzz ---
message(STATUS "Fetching HarfBuzz...")
FetchContent_Declare(
  harfbuzz
  GIT_REPOSITORY https://github.com/harfbuzz/harfbuzz.git
  GIT_TAG        8.3.0
)
# Disable FreeType support inside HarfBuzz to avoid build-system conflict.
# We will bridge them manually in our C++ code.
set(HB_HAVE_FREETYPE OFF CACHE BOOL "" FORCE)
set(HB_HAVE_GLIB OFF CACHE BOOL "" FORCE)
set(HB_HAVE_ICU OFF CACHE BOOL "" FORCE)
set(HB_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(HB_BUILD_UTILS OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(harfbuzz)

# --- Mushaf Renderer Bridge ---
add_library(mushaf_renderer SHARED
    src/mushaf_bridge.cpp
)

target_include_directories(mushaf_renderer PUBLIC
    ${freetype_SOURCE_DIR}/include
    ${harfbuzz_SOURCE_DIR}/src
)

target_link_libraries(mushaf_renderer
    PRIVATE
    freetype
    harfbuzz
    android
    log
)

set_target_properties(mushaf_renderer PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED YES
)