# kokkos/tools/fetch_analyse/CMakeLists.txt
# The fetch-growth analyser for examples/01: a small library over netcdf-c
# (reader + report, so tests/L1_test_fetch_analyse.cpp can drive it on a
# synthetic file) and the ww_fetch_analyse CLI.
#
# SPDX-License-Identifier: MIT
add_library(fetch_analyse_lib STATIC fetch_analyse.hpp fetch_analyse.cpp)
target_include_directories(fetch_analyse_lib PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(fetch_analyse_lib PUBLIC PkgConfig::NETCDF)
ww_apply_warnings(fetch_analyse_lib)

add_executable(ww_fetch_analyse main.cpp)
target_link_libraries(ww_fetch_analyse PRIVATE fetch_analyse_lib)
ww_apply_warnings(ww_fetch_analyse)
