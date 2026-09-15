# kokkos/tests/CMakeLists.txt
# GoogleTest suites. Naming convention: L1_* are unit tests against analytic or
# captured-Fortran fixtures; L2_* (Task 5) replay a whole WW3 regtest.
#
# SPDX-License-Identifier: MIT

# Build <name>.cpp into test executable <name> and register it with CTest.
function(ww_add_test name)
  add_executable(${name} ${name}.cpp)
  target_link_libraries(${name} PRIVATE ww_kokkos GTest::gtest_main)
  # WW_FIXTURE_DIR is where the committed binary fixtures live in the *source*
  # tree: they are inputs under version control, never build artefacts.
  target_compile_definitions(${name} PRIVATE
      WW_FIXTURE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/fixtures")
  ww_apply_warnings(${name})
  add_test(NAME ${name} COMMAND ${name})
  set_tests_properties(${name} PROPERTIES ENVIRONMENT "${WW_TEST_ENVIRONMENT}")
endfunction()

ww_add_test(L1_test_intro)
ww_add_test(L1_test_snl1_tables)
ww_add_test(L1_test_snl1_dia)

# The Fortran reference and the fixture generator. Not needed to run the tests --
# the fixture they produce is committed -- only to regenerate it.
if(WW_ENABLE_FORTRAN)
  add_subdirectory(fixtures)
endif()
