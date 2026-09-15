! examples/01-fetch-limited-growth/make_inputs.F90
! Write the ASCII depth and mask files that ww3_grid reads for example 01.
!
! WW3's grid preprocessor wants plain ASCII arrays for bathymetry and the
! land/sea mask, one row per line, in a layout you declare via IDLA. We use
! IDLA=1, which means "line by line, starting from the BOTTOM row (j=1)".
!
! Nothing clever happens here. The point of generating the files rather than
! committing static ones is that you can change NX/NY/DEPTH_M and re-run,
! which is exactly what the exercises ask you to do.
!
! Build and run (run.sh does this for you):
!     gfortran -O2 -std=f2018 -o make_inputs make_inputs.F90 && ./make_inputs
!
! SPDX-License-Identifier: MIT
program make_inputs
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none

  integer,       parameter :: nx = 61
  integer,       parameter :: ny = 5
  real(real64),  parameter :: depth_m = 250.0_real64  ! positive metres; ww3_grid.nml has DEPTH%SF = -1. to flip it
  real(real64),  parameter :: dx_km = 20.0_real64     ! must match RECT%SX in ww3_grid.nml

  ! Mask legend (from model/nml/ww3_grid.nml):
  !   -2 excluded boundary point (ice)   -1 excluded sea point (ice)
  !    0 excluded land point              1 sea point
  !    2 active boundary point            3 excluded grid point
  !    7 ice point
  integer, parameter :: land = 0
  integer, parameter :: sea  = 1

  integer :: i, j, unit

  open (newunit=unit, file='depth.inp', status='replace', action='write')
  do j = 1, ny
     write (unit, '(*(f0.1, :, 1x))') (depth_m, i = 1, nx)
  end do
  close (unit)

  open (newunit=unit, file='mask.inp', status='replace', action='write')
  do j = 1, ny
     ! i = 1 is the coastline.
     write (unit, '(*(i0, :, 1x))') (merge(land, sea, i == 1), i = 1, nx)
  end do
  close (unit)

  write (*, '(a, i0, a, i0, a, i0, a)') 'wrote depth.inp and mask.inp  (', nx, ' x ', ny, &
       ', ', nint(depth_m), ' m flat)'
  write (*, '(a, i0, a)') 'maximum fetch from the coast: ', nint(real(nx - 1, real64) * dx_km), ' km'
end program make_inputs
