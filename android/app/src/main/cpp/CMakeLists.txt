cmake_minimum_required(VERSION 3.22.1)

project("mathgod_giac" VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(GIAC_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/giac)

include_directories(
    ${GIAC_ROOT}/src
    ${GIAC_ROOT}/src/giac
    ${GIAC_ROOT}/src/giac/headers
)

file(GLOB_RECURSE GIAC_SOURCES
    "${GIAC_ROOT}/src/*.cpp"
    "${GIAC_ROOT}/src/*.cc"
)

# ─── EXCLUDE EVERYTHING NOT NEEDED FOR CORE CAS ────────────────────────────────
# Test files
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*/test/.*")

# Plotting and graphics (not needed on Android)
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*/plot.*")
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*/opengl.*")
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*/gui.*")
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*/fltk.*")
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*/glut.*")

# PARI library (not used in minimal build)
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*/pari.*")

# GeoGebra-specific wrappers (not needed)
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*/geogebra.*")
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*GeoGebraCAS.*")

# Node.js bindings (not needed)
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*/nodegiac.*")

# Simple interface examples (not needed)
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*/simpleInterface.*")

# Problematic individual files
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*desolve\\.cc")
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*signalprocessing.*")
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*gen\\.cc")
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*graphtheory.*")
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*global\\.cc")
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*help\\.cc")

# Demo files
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*-demo.*")
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*minigiac.*")

# ─── BUILD THE LIBRARY ─────────────────────────────────────────────────────────

add_library(giac SHARED
    ${CMAKE_CURRENT_SOURCE_DIR}/giac_wrapper.cpp
    ${GIAC_SOURCES}
)

target_compile_definitions(giac PRIVATE
    HAVE_CONFIG_H=1
    NO_GNUPLOT=1
    NO_PARI=1
    NO_FLTK=1
    ANDROID=1
    GIAC_COUT=0
    _POSIX_C_SOURCE=200809L
    _GNU_SOURCE
)

target_compile_options(giac PRIVATE
    -O2
    -fvisibility=hidden
    -fexceptions
    -frtti
    -Wno-unused-function
    -include unistd.h
)

find_library(log-lib log)
find_library(m-lib m)

target_link_libraries(giac
    ${log-lib}
    ${m-lib}
)

set_target_properties(giac PROPERTIES
    LINK_FLAGS_RELEASE "-s"
)