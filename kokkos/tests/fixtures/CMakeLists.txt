# kokkos/tests/fixtures/CMakeLists.txt
# The Fortran side of the L1 parity fixtures: the standalone W3SNL1/INSNL1
# reference and the generator that streams its answers into the committed
# snl1_nk25_nth24.bin. Nothing here is built into ww_kokkos -- it only ever runs
# when a human regenerates the fixture (`just snl1-fixtures`).
#
# SPDX-License-Identifier: MIT

set(WW_SNL1_FIXTURE ${CMAKE_CURRENT_SOURCE_DIR}/snl1_nk25_nth24.bin)

add_executable(gen_snl1_fixture snl1_ref.F90 gen_snl1_fixture.F90)
ww_apply_warnings(gen_snl1_fixture)

# Not part of ALL and not a test: regenerating rewrites a committed file, which
# must be a deliberate act with a reviewable diff.
add_custom_target(snl1-fixtures
    COMMAND $<TARGET_FILE:gen_snl1_fixture> ${WW_SNL1_FIXTURE}
    DEPENDS gen_snl1_fixture
    COMMENT "Regenerating ${WW_SNL1_FIXTURE} from the Fortran reference")

# Optional cross-check: the same record written by the *real* W3SNL1/INSNL1 out
# of a configured WW3 build, so the standalone reference can be proven to be a
# faithful copy rather than assumed to be one. Needs a WW3 built with a switch
# that includes NL1 -- with NL0 the model never compiles w3snl1md at all. See the
# note in kokkos/README.md.
if(WW_WW3_BUILD_DIR)
  # WW3's CMake and its older build scripts disagree about where the archive and
  # the .mod files land, so look in both places rather than hard-coding one.
  find_library(WW_WW3_LIBRARY NAMES ww3
      HINTS ${WW_WW3_BUILD_DIR} PATH_SUFFIXES lib src model/src NO_DEFAULT_PATH)
  find_path(WW_WW3_MODULE_DIR NAMES w3snl1md.mod
      HINTS ${WW_WW3_BUILD_DIR} PATH_SUFFIXES model/src/mod src/mod mod NO_DEFAULT_PATH)

  if(NOT WW_WW3_LIBRARY OR NOT WW_WW3_MODULE_DIR)
    message(WARNING
        "WW_WW3_BUILD_DIR=${WW_WW3_BUILD_DIR} has no libww3.a with a w3snl1md.mod "
        "next to it; skipping gen_snl1_ww3lib. A WW3 built with NL1 is required.")
  else()
    add_executable(gen_snl1_ww3lib gen_snl1_ww3lib.F90)
    ww_apply_warnings(gen_snl1_ww3lib)
    target_include_directories(gen_snl1_ww3lib PRIVATE ${WW_WW3_MODULE_DIR})
    target_link_libraries(gen_snl1_ww3lib PRIVATE ${WW_WW3_LIBRARY})
    if(NETCDFF_FOUND)
      target_link_libraries(gen_snl1_ww3lib PRIVATE PkgConfig::NETCDFF)
    endif()
    find_package(MPI COMPONENTS Fortran)
    if(MPI_Fortran_FOUND)
      target_link_libraries(gen_snl1_ww3lib PRIVATE MPI::MPI_Fortran)
    endif()
  endif()
endif()
