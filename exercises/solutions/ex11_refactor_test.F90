! exercises/solutions/ex11_refactor_test.F90
! Exercise 11 -- the per-routine parity test: legacy vs refactored on random
! input, to 1e-6 relative. This is the smallest instance of the discipline the
! whole port runs on: never change a routine without a test that says the old
! and the new answer agree, and say how closely.
!
! Build and run (or `ctest` in ../solutions/build, see CMakeLists.txt):
!     gfortran -O2 -std=f2018 -Wall -fimplicit-none -o ex11_test ex11_refactor.F90 ex11_refactor_test.F90
!     ./ex11_test
!
! SPDX-License-Identifier: MIT
program ex11_refactor_test
  use, intrinsic :: iso_fortran_env, only: real32, real64, error_unit
  use w3sds_mod, only: w3sds_new
  implicit none

  ! The legacy routine has no module, so the caller must spell its interface
  ! out -- or, as WW3 mostly does, not spell it out and hope. Spelling it out
  ! here is what lets -Wall check the call at all.
  interface
     subroutine w3sds_old(a, nk, nth, sig, dsii, dth, cds, s, d)
       import :: real32
       integer      :: nk, nth
       real(real32) :: a(nk*nth), sig(nk), dsii(nk), dth, cds
       real(real32) :: s(nk*nth), d(nk*nth)
     end subroutine w3sds_old
  end interface

  integer,      parameter :: nk = 32, nth = 24, ntrial = 5
  real(real32), parameter :: xfr = 1.1_real32, freq1 = 0.04118_real32
  real(real32), parameter :: cds = 2.36e-5_real32
  real(real64), parameter :: tol = 1.0e-6_real64

  real(real32) :: a2(nth, nk), s2(nth, nk), d2(nth, nk)      ! (theta, k) for the new routine
  real(real32) :: a1(nth*nk), s1(nth*nk), d1(nth*nk)         ! flattened for the old one
  real(real32) :: sig(nk), dsii(nk), dth
  real(real64) :: err_s, err_d, worst
  integer      :: ik, trial

  ! WW3's default spectral grid: geometric bands, uniform directions.
  do ik = 1, nk
     sig(ik)  = 2.0_real32 * (4.0_real32 * atan(1.0_real32)) * freq1 * xfr**(ik - 1)
     dsii(ik) = sig(ik) * (xfr - 1.0_real32 / xfr) * 0.5_real32
  end do
  dth = 2.0_real32 * (4.0_real32 * atan(1.0_real32)) / real(nth, real32)

  call random_init(repeatable=.true., image_distinct=.false.)

  worst = 0.0_real64
  do trial = 1, ntrial
     call random_number(a2)
     a2 = a2 * 1.0e-2_real32                 ! a plausible action-density magnitude
     a1 = reshape(a2, [nth*nk])              ! same memory order: theta fastest

     call w3sds_old(a1, nk, nth, sig, dsii, dth, cds, s1, d1)
     call w3sds_new(a2, sig, dsii, dth, cds, s2, d2)

     err_s = rel_err(reshape(s2, [nth*nk]), s1)
     err_d = rel_err(reshape(d2, [nth*nk]), d1)
     worst = max(worst, err_s, err_d)
     write (*, '(a, i0, a, es9.2, a, es9.2)') 'trial ', trial, ': max rel err S = ', err_s, &
          '  D = ', err_d
  end do

  if (worst <= tol) then
     write (*, '(a, es9.2, a, es9.2, a)') 'ex11_refactor_test: PASS (worst ', worst, ' <= ', tol, ')'
  else
     write (error_unit, '(a, es9.2, a, es9.2, a)') 'ex11_refactor_test: FAIL (worst ', worst, &
          ' > ', tol, ')'
     error stop 1
  end if

contains

  !> max_i |x_i - y_i| / max(|y_i|, tiny), in double so the metric itself is exact enough.
  pure function rel_err(x, y) result(e)
    real(real32), intent(in) :: x(:), y(:)
    real(real64) :: e
    e = maxval(abs(real(x, real64) - real(y, real64)) / max(abs(real(y, real64)), 1.0e-30_real64))
  end function rel_err

end program ex11_refactor_test
