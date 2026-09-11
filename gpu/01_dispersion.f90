! A kernel that is actually WW3-shaped: solve the linear dispersion
! relation for wavenumber at every (grid point, frequency) pair.
!
!     sigma^2 = g * k * tanh(k * d)
!
! Given sigma and depth d, find k. No closed form, so Newton-Raphson from
! a good initial guess. WW3 does this constantly -- every grid point, every
! frequency, whenever the depth or current changes.
!
! This is a GOOD GPU kernel and a useful contrast with W3SRCEMD:
!   * embarrassingly parallel over (point, frequency)
!   * tiny working set per thread -- a handful of scalars, no arrays
!   * arithmetic-heavy relative to the data moved
!   * uniform trip count if you fix the iteration count
!
! W3SRCEMD is the opposite on every one of those, which is why the
! published WW3 GPU port got 1.3x and this will get a lot more.
!
!   nvfortran -O3 -acc -gpu=cc89 -Minfo=accel -o 01_dispersion 01_dispersion.f90
!   nvfortran -O3 -acc=multicore            -o 01_dispersion_cpu 01_dispersion.f90

program dispersion
  implicit none
  integer, parameter :: npt = 200000     ! grid points
  integer, parameter :: nk  = 32          ! frequency bins
  integer, parameter :: niter = 8         ! fixed Newton iterations
  real, parameter :: g = 9.806
  real, parameter :: pi = 3.14159265358979
  real, parameter :: freq1 = 0.04118, xfr = 1.1

  real, allocatable :: depth(:), sigma(:), k(:,:)
  real :: kd, f, fp, x, t
  integer :: ip, ik, it
  real :: t0, t1

  allocate(depth(npt), sigma(nk), k(npt, nk))

  do ip = 1, npt
     depth(ip) = 2.0 + 5000.0 * real(mod(ip, 997)) / 997.0
  end do
  do ik = 1, nk
     sigma(ik) = 2.0 * pi * freq1 * xfr**(ik - 1)
  end do

  call cpu_time(t0)

  !$acc data copyin(depth, sigma) copyout(k)
  !$acc parallel loop collapse(2) private(x, kd, f, fp, t, it)
  do ik = 1, nk
     do ip = 1, npt
        ! Initial guess: deep-water k, corrected towards shallow.
        ! (Eckart's approximation -- good to a few percent everywhere,
        !  which Newton then cleans up in 3-4 iterations.)
        x = sigma(ik)**2 / g
        x = x / sqrt(tanh(x * depth(ip)))

        do it = 1, niter
           kd = x * depth(ip)
           t  = tanh(kd)
           f  = g * x * t - sigma(ik)**2
           fp = g * t + g * x * depth(ip) * (1.0 - t * t)
           x  = x - f / fp
        end do

        k(ip, ik) = x
     end do
  end do
  !$acc end data

  call cpu_time(t1)

  print '(a,i0,a,i0,a,i0,a)', ' solved ', npt, ' x ', nk, ' = ', npt*nk, ' dispersion relations'
  print '(a,f10.4,a)', ' wall time (cpu_time, so host-side): ', t1 - t0, ' s'
  print '(a,es14.6)', ' k(1,1)      = ', k(1,1)
  print '(a,es14.6)', ' k(npt,nk)   = ', k(npt,nk)

  ! Residual check on one value -- never trust a GPU kernel you haven't verified.
  ip = npt / 2; ik = nk / 2
  print '(a,es14.6)', ' residual at midpoint = ', &
       g * k(ip,ik) * tanh(k(ip,ik) * depth(ip)) - sigma(ik)**2

  deallocate(depth, sigma, k)
end program dispersion
