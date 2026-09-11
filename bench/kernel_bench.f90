! ---------------------------------------------------------------------
! kernel_bench.f90 -- a WW3-shaped source-term kernel, timed on CPU and GPU.
!
! WHY A PROXY AND NOT WW3 ITSELF:
!   WW3 has no GPU code path. You cannot benchmark "WW3 on the 4090" because
!   that binary does not exist. What you CAN do is benchmark a kernel with
!   the same shape as WW3's hot spot -- W3SRCEMD, the source-term integration
!   -- and learn where the crossover is on your own hardware.
!
! WHAT THIS MIMICS:
!   * data layout spec(nspec, npt): spectral bins contiguous, points outer.
!     This is WW3's natural layout and it is why the arrays are enormous.
!   * an outer loop over sea points, an inner loop over frequency-direction
!     bins, and a sub-iteration loop standing in for WW3's adaptive
!     source-term timestepping (DTMIN).
!   * a wind-input term and a dissipation term that nearly cancel, which is
!     the actual numerical character of Sin + Sds.
!
! WHAT IT DELIBERATELY DOES NOT MIMIC:
!   * the register pressure of the real W3SRCEMD, which the GMD 2023 paper
!     identified as an occupancy killer. This kernel is friendlier than the
!     real thing, so treat your GPU number as an OPTIMISTIC bound.
!
! BUILD (see Makefile):
!   gfortran -O3 -fopenmp            -o kernel_cpu  kernel_bench.f90
!   nvfortran -O3 -acc=multicore     -o kernel_mc   kernel_bench.f90
!   nvfortran -O3 -acc -gpu=cc89     -o kernel_gpu  kernel_bench.f90
!
! RUN:
!   ./kernel_gpu [npt] [nsub] [reps]      defaults: 50000 8 20
!
! TIMING NOTE: this uses SYSTEM_CLOCK (wall time), not CPU_TIME. CPU_TIME
! sums across OpenMP threads, so it reports ~N times the wall time on N
! threads and makes threading look like a slowdown. That mistake is very
! common in homemade benchmarks.
! ---------------------------------------------------------------------
program kernel_bench
  implicit none

  integer, parameter :: nk = 32, nth = 36
  integer, parameter :: nspec = nk * nth          ! 1152 bins per point

  integer :: npt, nsub, reps
  real,    allocatable :: spec(:,:)               ! action density
  real,    allocatable :: wind(:), depth(:)
  real,    allocatable :: sigma(:)

  integer :: ip, is, it, r
  real    :: sin_t, sds_t, growth, dt, x
  real(kind=8) :: t_compute, t_transfer, t_total
  real(kind=8) :: bytes, checksum

  call read_args(npt, nsub, reps)

  allocate(spec(nspec, npt), wind(npt), depth(npt), sigma(nspec))

  call init(spec, wind, depth, sigma, npt, nspec)

  bytes = 4.0d0 * real(nspec, 8) * real(npt, 8)
  write(*,'(a)')        ' --------------------------------------------------'
  write(*,'(a,i0,a,i0,a,i0)') ' points = ', npt, '   spectral bins = ', nspec, &
                              '   sub-iterations = ', nsub
  write(*,'(a,f10.2,a)') ' spectrum array   : ', bytes / 1.0d6, ' MB'
  write(*,'(a,i0)')      ' repetitions      : ', reps
  write(*,'(a)')        ' --------------------------------------------------'

  dt = 10.0    ! DTMIN, seconds

  ! ------------------------------------------------------------------
  ! Phase 1: data resident on the device for the whole run.
  ! This is the BEST case -- what you get if you restructure the model so
  ! the spectrum never leaves the GPU. It is also what WW3's current
  ! structure makes hard, because the propagation step wants it back.
  ! ------------------------------------------------------------------
  !$acc data copyin(wind, depth, sigma) copy(spec)

  call tic(t_total)
  do r = 1, reps
     !$acc parallel loop gang present(spec, wind, depth, sigma) &
     !$acc   private(is, it, sin_t, sds_t, growth, x)
     !$omp parallel do private(is, it, sin_t, sds_t, growth, x) schedule(static)
     do ip = 1, npt
        !$acc loop vector
        do is = 1, nspec
           x = spec(is, ip)
           do it = 1, nsub
              ! wind input: grows with wind speed and inverse phase speed
              sin_t = 1.2e-4 * wind(ip) * sigma(is) * x
              ! saturation-style dissipation: nonlinear in the local density
              sds_t = 2.6e-3 * sigma(is) * x * sqrt(abs(x) + 1.0e-9)
              ! the near-cancellation that defines a spectral wave model
              growth = sin_t - sds_t
              x = x + dt * growth
              if (x < 0.0) x = 0.0
           end do
           spec(is, ip) = x
        end do
     end do
  end do
  call toc(t_total, t_compute)

  !$acc end data

  checksum = 0.0d0
  !$omp parallel do reduction(+:checksum)
  do ip = 1, npt
     checksum = checksum + real(sum(spec(:, ip)), 8)
  end do

  write(*,'(a)') ' RESIDENT DATA (best case: spectrum stays on device)'
  write(*,'(a,f12.4,a)') '   total wall time : ', t_compute, ' s'
  write(*,'(a,f12.4,a)') '   per repetition  : ', t_compute / reps, ' s'
  write(*,'(a,es16.8)')  '   checksum        : ', checksum

  ! ------------------------------------------------------------------
  ! Phase 2: copy the spectrum in and out every repetition.
  ! This is what a naive offload of W3SRCEMD inside WW3's existing
  ! timestep loop actually costs -- and it is precisely the bottleneck
  ! the GMD 2023 paper hit, on hardware with NVLink. You have PCIe.
  ! ------------------------------------------------------------------
  call init(spec, wind, depth, sigma, npt, nspec)

  call tic(t_total)
  do r = 1, reps
     !$acc data copyin(wind, depth, sigma) copy(spec)
     !$acc parallel loop gang present(spec, wind, depth, sigma) &
     !$acc   private(is, it, sin_t, sds_t, growth, x)
     !$omp parallel do private(is, it, sin_t, sds_t, growth, x) schedule(static)
     do ip = 1, npt
        !$acc loop vector
        do is = 1, nspec
           x = spec(is, ip)
           do it = 1, nsub
              sin_t = 1.2e-4 * wind(ip) * sigma(is) * x
              sds_t = 2.6e-3 * sigma(is) * x * sqrt(abs(x) + 1.0e-9)
              growth = sin_t - sds_t
              x = x + dt * growth
              if (x < 0.0) x = 0.0
           end do
           spec(is, ip) = x
        end do
     end do
     !$acc end data
  end do
  call toc(t_total, t_transfer)

  write(*,'(a)') ' COPY EVERY STEP (naive in-place offload)'
  write(*,'(a,f12.4,a)') '   total wall time : ', t_transfer, ' s'
  write(*,'(a,f12.4,a)') '   per repetition  : ', t_transfer / reps, ' s'
  write(*,'(a,f12.2,a)') '   penalty         : ', t_transfer / max(t_compute, 1.0d-9), 'x'
  write(*,'(a,f12.2,a)') '   implied H<->D   : ', &
       2.0d0 * bytes * reps / max(t_transfer - t_compute, 1.0d-9) / 1.0d9, ' GB/s'
  write(*,'(a)') ' --------------------------------------------------'
  write(*,'(a)') ' On a CPU build the two phases should be nearly identical:'
  write(*,'(a)') ' there is no transfer. The gap you see on the GPU build IS'
  write(*,'(a)') ' the reason the published WW3 port only reached ~1.3x.'

  deallocate(spec, wind, depth, sigma)

contains

  subroutine read_args(np, ns, nr)
    integer, intent(out) :: np, ns, nr
    character(len=32) :: arg
    np = 50000; ns = 8; nr = 20
    if (command_argument_count() >= 1) then
       call get_command_argument(1, arg); read(arg,*) np
    end if
    if (command_argument_count() >= 2) then
       call get_command_argument(2, arg); read(arg,*) ns
    end if
    if (command_argument_count() >= 3) then
       call get_command_argument(3, arg); read(arg,*) nr
    end if
  end subroutine read_args

  subroutine init(sp, wd, dp, sg, np, nsp)
    integer, intent(in) :: np, nsp
    real, intent(out) :: sp(nsp, np), wd(np), dp(np), sg(nsp)
    integer :: i, j
    real, parameter :: pi = 3.14159265358979
    real, parameter :: freq1 = 0.04118, xfr = 1.1
    do j = 1, nsp
       sg(j) = 2.0 * pi * freq1 * xfr**real(mod(j - 1, 32))
    end do
    do i = 1, np
       wd(i) = 5.0 + 15.0 * real(mod(i, 101)) / 101.0
       dp(i) = 10.0 + 4000.0 * real(mod(i, 997)) / 997.0
       do j = 1, nsp
          sp(j, i) = 1.0e-3 * exp(-0.5 * (real(mod(j, 32)) - 8.0)**2 / 9.0)
       end do
    end do
  end subroutine init

  subroutine tic(t)
    real(kind=8), intent(out) :: t
    integer(kind=8) :: c, cr
    call system_clock(c, cr)
    t = real(c, 8) / real(cr, 8)
  end subroutine tic

  subroutine toc(t0, dt_out)
    real(kind=8), intent(in)  :: t0
    real(kind=8), intent(out) :: dt_out
    integer(kind=8) :: c, cr
    call system_clock(c, cr)
    dt_out = real(c, 8) / real(cr, 8) - t0
  end subroutine toc

end program kernel_bench
