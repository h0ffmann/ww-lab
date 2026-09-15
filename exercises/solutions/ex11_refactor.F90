! exercises/solutions/ex11_refactor.F90
! Exercise 11 solution -- a WW3-style routine, before and after.
!
! W3SDS_OLD is the shape of a great many WAVEWATCH III routines: an external
! subroutine (no module, so every caller gets an IMPLICIT INTERFACE and the
! compiler checks nothing), a flattened 1-D spectrum indexed by hand, dummy
! arguments without INTENT, and an AUTOMATIC ARRAY on the stack whose size is
! only known at the call. It computes a Komen-type whitecapping term, the
! shape of W3SDS1: a mean energy and mean frequency from the spectrum, a
! steepness-like parameter from them, and a dissipation rate D(k) that
! multiplies the spectrum.
!
! W3SDS_NEW is the same arithmetic, refactored the way lesson 10 asks:
!   * a MODULE procedure -- explicit interface, the compiler checks the call;
!   * PURE, with INTENT on every argument;
!   * assumed-shape 2-D arrays (theta, k) declared CONTIGUOUS, no hand-rolled
!     1-D indexing;
!   * no automatic array: the mean parameters come out of intrinsic
!     reductions, so nothing of size NK lives on the stack.
! Same expressions in the same order, so the two agree to round-off;
! ex11_refactor_test.F90 checks that on random input.
!
! Both use WW3's working precision, single (real32), spelled out.
!
! SPDX-License-Identifier: MIT

! --------------------------------------------------------------------------
! The legacy routine. Deliberately not in a module.
! --------------------------------------------------------------------------
subroutine w3sds_old(a, nk, nth, sig, dsii, dth, cds, s, d)
  use, intrinsic :: iso_fortran_env, only: real32
  implicit none
  integer      :: nk, nth
  real(real32) :: a(nk*nth), sig(nk), dsii(nk), dth, cds
  real(real32) :: s(nk*nth), d(nk*nth)
  real(real32) :: e1(nk)                 ! automatic array: size known only at the call
  real(real32) :: emean, fmean, alpha, alfpm, fac, tpi, grav
  integer      :: ik, ith, isp

  tpi   = 8.0_real32 * atan(1.0_real32)
  grav  = 9.806_real32
  alfpm = 3.02e-3_real32                 ! Pierson-Moskowitz steepness, WW3's ALPHA_PM

  ! 1-D frequency spectrum and its zeroth / first moments.
  emean = 0.0_real32
  fmean = 0.0_real32
  do ik = 1, nk
     e1(ik) = 0.0_real32
     do ith = 1, nth
        isp = ith + (ik - 1) * nth
        e1(ik) = e1(ik) + a(isp)
     end do
     e1(ik) = e1(ik) * sig(ik) * dth     ! action -> energy, integrate over theta
     emean  = emean + e1(ik) * dsii(ik)
     fmean  = fmean + e1(ik) * dsii(ik) * sig(ik)
  end do
  fmean = fmean / max(emean, 1.0e-30_real32) / tpi   ! mean frequency in Hz

  ! Steepness-like parameter and the dissipation rate.
  alpha = emean * (tpi * fmean)**4 / grav**2
  fac   = cds * (alpha / alfpm)**2 * fmean
  do ik = 1, nk
     do ith = 1, nth
        isp = ith + (ik - 1) * nth
        d(isp) = -fac * (sig(ik) / (tpi * fmean))**2
        s(isp) = d(isp) * a(isp)
     end do
  end do
end subroutine w3sds_old

! --------------------------------------------------------------------------
! The modern twin.
! --------------------------------------------------------------------------
module w3sds_mod
  use, intrinsic :: iso_fortran_env, only: real32
  implicit none
  private
  public :: w3sds_new

  real(real32), parameter :: tpi   = 8.0_real32 * atan(1.0_real32)
  real(real32), parameter :: grav  = 9.806_real32
  real(real32), parameter :: alfpm = 3.02e-3_real32

contains

  !> Komen-type whitecapping: S = D * A with D(k) from the spectrum's mean
  !> energy and mean frequency. A, S, D are (theta, k); SIG and DSII are per band.
  pure subroutine w3sds_new(a, sig, dsii, dth, cds, s, d)
    real(real32), intent(in),  contiguous :: a(:, :)   ! action density, (nth, nk)
    real(real32), intent(in),  contiguous :: sig(:)    ! radian frequency per band
    real(real32), intent(in),  contiguous :: dsii(:)   ! band width
    real(real32), intent(in)              :: dth       ! direction increment
    real(real32), intent(in)              :: cds       ! dissipation constant
    real(real32), intent(out), contiguous :: s(:, :)   ! source term
    real(real32), intent(out), contiguous :: d(:, :)   ! its diagonal (rate)
    real(real32) :: e1, emean, fmean, alpha, fac
    integer      :: ik, ith, nk

    nk = size(sig)
    emean = 0.0_real32
    fmean = 0.0_real32
    do ik = 1, nk
       ! The automatic array is gone: the band sum is a scalar. Summed in the
       ! same order as the legacy loop so the two agree to round-off.
       e1 = 0.0_real32
       do ith = 1, size(a, 1)
          e1 = e1 + a(ith, ik)
       end do
       e1    = e1 * sig(ik) * dth
       emean = emean + e1 * dsii(ik)
       fmean = fmean + e1 * dsii(ik) * sig(ik)
    end do
    fmean = fmean / max(emean, 1.0e-30_real32) / tpi

    alpha = emean * (tpi * fmean)**4 / grav**2
    fac   = cds * (alpha / alfpm)**2 * fmean
    do ik = 1, nk
       d(:, ik) = -fac * (sig(ik) / (tpi * fmean))**2
       s(:, ik) = d(:, ik) * a(:, ik)
    end do
  end subroutine w3sds_new

end module w3sds_mod
