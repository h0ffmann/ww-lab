# kokkos/tests/CMakeLists.txt
# GoogleTest suites. Naming convention: L1_* are unit tests against analytic or
# captured-Fortran fixtures; L2_* (Task 5) replay a whole WW3 regtest.
#
# SPDX-License-Identifier: MIT

# Build <name>.cpp into test executable <name> and register it with CTest.
function(ww_add_test name)
  add_executable(${name} ${name}.cpp)
  target_link_libraries(${name} PRIVATE ww_kokkos GTest::gtest_main)
  ww_apply_warnings(${name})
  add_test(NAME ${name} COMMAND ${name})
  set_tests_properties(${name} PROPERTIES ENVIRONMENT "${WW_TEST_ENVIRONMENT}")
endfunction()

ww_add_test(L1_test_intro)
