! The same idea in standard ISO Fortran -- no directives at all.
!
!   nvfortran -O3 -stdpar=gpu -gpu=cc89 -Minfo=stdpar -o 02_dc 02_do_concurrent.f90
!   nvfortran -O3 -stdpar=multicore                   -o 02_dc_cpu 02_do_concurrent.f90
!   gfortran  -O3                                     -o 02_dc_ser 02_do_concurrent.f90
!
! Three compilers, three targets, ONE source file, no pragmas. This is why
! `do concurrent` is the nicest on-ramp if you are writing new Fortran
! rather than porting old Fortran.
!
! The catch: you are trusting the compiler to prove the loop iterations are
! independent. If it can't, it silently runs serially. -Minfo=stdpar tells
! you which way it went -- always check.
!
! -stdpar=gpu also switches allocatables to CUDA managed memory, so the
! data movement happens implicitly. Convenient, and also the reason a
! naively-ported code can end up thrashing PCIe without you noticing.

program dc_dispersion
  implicit none
  integer, parameter :: npt = 200000, nk = 32, niter = 8
  real, parameter :: g = 9.806, pi = 3.14159265358979
  real, parameter :: freq1 = 0.04118, xfr = 1.1

  real, allocatable :: depth(:), sigma(:), k(:,:)
  integer :: ip, ik, it
  real :: x, kd, f, fp, t

  allocate(depth(npt), sigma(nk), k(npt, nk))
  depth = [(2.0 + 5000.0 * real(mod(ip,997))/997.0, ip = 1, npt)]
  sigma = [(2.0*pi*freq1*xfr**(ik-1), ik = 1, nk)]

  ! LOCAL() is Fortran 2018 locality. If your nvfortran rejects it, drop the
  ! clause -- but then check -Minfo=stdpar actually still offloads the loop.
  do concurrent (ip = 1:npt, ik = 1:nk) local(x, kd, f, fp, t, it)
     x = sigma(ik)**2 / g
     x = x / sqrt(tanh(x * depth(ip)))
     do it = 1, niter
        kd = x * depth(ip)
        t  = tanh(kd)
        f  = g * x * t - sigma(ik)**2
        fp = g * t + g * x * depth(ip) * (1.0 - t*t)
        x  = x - f / fp
     end do
     k(ip, ik) = x
  end do

  print '(a,es14.6)', ' k(1,1)    = ', k(1,1)
  print '(a,es14.6)', ' k(npt,nk) = ', k(npt,nk)
  deallocate(depth, sigma, k)
end program dc_dispersion
