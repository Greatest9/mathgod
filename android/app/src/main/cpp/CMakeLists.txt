cmake_minimum_required(VERSION 3.22.1)

project("mathgod_giac" VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(GIAC_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/giac)

include_directories(
    ${GIAC_ROOT}/src
    ${GIAC_ROOT}/src/giac
)

file(GLOB_RECURSE GIAC_SOURCES
    "${GIAC_ROOT}/src/*.cpp"
    "${GIAC_ROOT}/src/*.cc"
)

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
)

target_compile_options(giac PRIVATE
    -O2
    -fvisibility=hidden
    -fexceptions
    -frtti
    -Wno-unused-function
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