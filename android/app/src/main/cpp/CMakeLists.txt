cmake_minimum_required(VERSION 3.22.1)

project("mathgod_giac" VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(GIAC_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/giac)

# ─── ABI → prebuilt path mapping ───────────────────────────────────────────────
if(ANDROID_ABI STREQUAL "arm64-v8a")
    set(GIAC_ABI_DIR "arm-v8")
elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
    set(GIAC_ABI_DIR "arm-v7")
elseif(ANDROID_ABI STREQUAL "x86_64")
    set(GIAC_ABI_DIR "x86-64")
elseif(ANDROID_ABI STREQUAL "x86")
    set(GIAC_ABI_DIR "x86")
else()
    message(FATAL_ERROR "Unsupported ABI: ${ANDROID_ABI}")
endif()

set(GIAC_PREBUILT_DIR ${GIAC_ROOT}/src/jni/prebuilt/android/${GIAC_ABI_DIR})
set(GIAC_HEADER_DIR   ${GIAC_ROOT}/src/giac/headers/android/${GIAC_ABI_DIR})

include_directories(
    ${GIAC_ROOT}/src
    ${GIAC_ROOT}/src/giac
    ${GIAC_ROOT}/src/giac/headers
    ${GIAC_HEADER_DIR}
)

file(GLOB_RECURSE GIAC_SOURCES
    "${GIAC_ROOT}/src/*.cpp"
    "${GIAC_ROOT}/src/*.cc"
)

# ─── EXCLUDE EVERYTHING NOT NEEDED FOR CORE CAS ────────────────────────────────
# Test files
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*/test/.*")

# Graphics (plot.cc is needed, but opengl/gui/fltk/glut are not)
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*/opengl.*")
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*/gui.*")
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*/fltk.*")
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*/glut.*")

# GeoGebra-specific wrappers (not needed)
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*/geogebra.*")
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*GeoGebraCAS.*")

# Node.js bindings (not needed)
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*/nodegiac.*")

# Simple interface examples (not needed)
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*/simpleInterface.*")

# Only exclude files that genuinely cause compile errors
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*signalprocessing.*")
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*graphtheory.*")

# Demo files
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*-demo.*")
list(FILTER GIAC_SOURCES EXCLUDE REGEX ".*minigiac.*")

# ─── BUILD THE LIBRARY ─────────────────────────────────────────────────────────

add_library(giac SHARED
    ${CMAKE_CURRENT_SOURCE_DIR}/giac_wrapper.cpp
    ${GIAC_SOURCES}
)

# ─── FIX FOR global.cc fread error ────────────────────────────────────────────
set_source_files_properties(${GIAC_ROOT}/src/giac/cpp/global.cc PROPERTIES COMPILE_FLAGS "-U_FORTIFY_SOURCE")

target_compile_definitions(giac PRIVATE
    HAVE_CONFIG_H=1
    NO_GNUPLOT=1
    NO_FLTK=1
    ANDROID=1
    GIAC_COUT=0
    _POSIX_C_SOURCE=200809L
    _GNU_SOURCE
    GIAC_GGB=1
)

target_compile_options(giac PRIVATE
    -O2
    -fvisibility=hidden
    -fexceptions
    -frtti
    -Wno-unused-function
    -include unistd.h
    -Wno-c++11-narrowing
)

find_library(log-lib log)
find_library(m-lib m)

# ─── Prebuilt GMP + MPFR ──────────────────────────────────────────────────────
add_library(gmp  STATIC IMPORTED)
add_library(mpfr STATIC IMPORTED)
set_target_properties(gmp  PROPERTIES IMPORTED_LOCATION ${GIAC_PREBUILT_DIR}/libgmp.a)
set_target_properties(mpfr PROPERTIES IMPORTED_LOCATION ${GIAC_PREBUILT_DIR}/libmpfr.a)

target_link_libraries(giac
    mpfr
    gmp
    ${log-lib}
    ${m-lib}
)

set_target_properties(giac PROPERTIES
    LINK_FLAGS_RELEASE "-s"
)