# kokkos/tools/bench_case/CMakeLists.txt
# The benchmark-case generator: a plain C++ library (no Kokkos, no NetCDF) that
# writes a self-contained WW3 run directory, and the ww_bench_case CLI over it.
# The library is what tests/L1_test_bench_case.cpp pins to the Python fixture.
#
# SPDX-License-Identifier: MIT
add_library(bench_case_lib STATIC bench_case.hpp bench_case.cpp)
target_include_directories(bench_case_lib PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
ww_apply_warnings(bench_case_lib)

add_executable(ww_bench_case main.cpp)
target_link_libraries(ww_bench_case PRIVATE bench_case_lib)
ww_apply_warnings(ww_bench_case)
