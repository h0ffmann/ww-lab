# kokkos/src/ww_kokkos/CMakeLists.txt
# Sources of the portable kernel library. Only headers so far: Task 3 adds
# snl1_dia.{hpp,cpp} and snl1_tables.{hpp,cpp} here.
#
# SPDX-License-Identifier: MIT
target_sources(ww_kokkos PRIVATE real.hpp spectrum_fixtures.hpp)
