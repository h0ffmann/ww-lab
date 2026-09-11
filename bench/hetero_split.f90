! ---------------------------------------------------------------------
! hetero_split.f90 -- can the i9 and the 4090 work on the same problem
!                     AT THE SAME TIME, and does it help?
!
! THE ANSWER IS YES, IT IS POSSIBLE. Whether it PAYS is an empirical
! question about your specific hardware, and this program measures it.
!
! HOW IT WORKS:
!   The point loop is split at index `ncpu`. Points 1..ncpu are computed
!   by the host with OpenMP; points ncpu+1..npt are computed on the GPU.
!   The GPU kernel is launched with `async`, which returns control to the
!   host IMMEDIATELY -- so the OpenMP loop runs while the GPU is busy.
!   `!$acc wait` at the end joins them.
!
!   The program sweeps the split fraction from 0.0 (all GPU) to 1.0
!   (all CPU) and reports the wall time at each, so you can read the
!   optimum straight off. If your best time is at 0.0 or 1.0, the
!   heterogeneous split is not worth it on your box.
!
!   The theoretical optimum is the fraction f where the two finish
!   together:   f / R_cpu  =  (1-f) / R_gpu   =>   f = R_cpu / (R_cpu + R_gpu)
!   and the best possible speedup over the faster device alone is
!   (R_cpu + R_gpu) / max(R_cpu, R_gpu). If the GPU is 5x the CPU, the
!   most you can win by adding the CPU is 20%. That is the whole story.
!
! THE HONEST CAVEATS, which the numbers will show you:
!   1. The host-side data for the GPU's slice has to cross PCIe each
!      step, and this program charges you for that (`update device` /
!      `update self`). That cost is what usually eats the gain.
!   2. On an Intel i9 with P-cores and E-cores, the OpenMP half runs at
!      the pace of its slowest thread. Try pinning to P-cores only:
!         OMP_NUM_THREADS=8 OMP_PLACES=cores OMP_PROC_BIND=close ./hetero
!      and compare against using every logical core.
!   3. In real WW3 the source-term step and the propagation step are
!      sequentially dependent within a timestep, so you cannot split them
!      this cleanly -- you would have to pipeline across subdomains.
!      This program is the optimistic case.
!
! BUILD:  nvfortran -O3 -acc -gpu=cc89 -mp -o hetero_split hetero_split.f90
! RUN:    ./hetero_split [npt] [nsub] [reps]      defaults: 50000 8 10
! ---------------------------------------------------------------------
program hetero_split
  implicit none

  integer, parameter :: nk = 32, nth = 36
  integer, parameter :: nspec = nk * nth

  integer :: npt, nsub, reps
  real,    allocatable :: spec(:,:), wind(:), sigma(:)
  integer :: ncpu, istep, r
  real    :: frac, dt
  real(kind=8) :: t0, elapsed, best_time, best_frac
  real(kind=8) :: t_cpu_only, t_gpu_only

  call read_args(npt, nsub, reps)
  allocate(spec(nspec, npt), wind(npt), sigma(nspec))
  dt = 10.0

  write(*,'(a)') ' ------------------------------------------------------'
  write(*,'(a,i0,a,i0)') ' points = ', npt, '   spectral bins = ', nspec
  write(*,'(a,f10.2,a)') ' spectrum array : ', &
       4.0d0 * real(nspec,8) * real(npt,8) / 1.0d6, ' MB'
  write(*,'(a)') ' ------------------------------------------------------'
  write(*,'(a)') '   cpu_frac    wall [s]   note'

  best_time = huge(1.0d0); best_frac = -1.0d0
  t_cpu_only = 0.0d0; t_gpu_only = 0.0d0

  do istep = 0, 10
     frac = real(istep) / 10.0
     ncpu = nint(frac * real(npt))

     call init(spec, wind, sigma, npt, nspec)

     !$acc enter data copyin(spec, wind, sigma)

     call tic(t0)
     do r = 1, reps

        ! -- refresh the device with whatever the host changed last step.
        !    This is the PCIe cost of keeping two devices coherent, and
        !    it is the thing that usually kills heterogeneous splits.
        if (ncpu > 0 .and. ncpu < npt) then
           !$acc update device(spec(:, 1:ncpu)) async(1)
        end if

        ! -- GPU slice, launched asynchronously: control returns at once
        call gpu_slice(spec, wind, sigma, ncpu + 1, npt, nspec, nsub, dt)

        ! -- CPU slice runs concurrently with the GPU kernel above
        call cpu_slice(spec, wind, sigma, 1, ncpu, nspec, nsub, dt)

        ! -- pull the GPU's results back and join
        if (ncpu < npt) then
           !$acc update self(spec(:, ncpu+1:npt)) async(1)
        end if
        !$acc wait(1)
     end do
     call toc(t0, elapsed)

     !$acc exit data delete(spec, wind, sigma)

     if (istep == 0)  t_gpu_only = elapsed
     if (istep == 10) t_cpu_only = elapsed

     if (elapsed < best_time) then
        best_time = elapsed
        best_frac = real(frac, 8)
     end if

     if (istep == 0) then
        write(*,'(f11.2,f12.4,a)') frac, elapsed, '   all GPU'
     else if (istep == 10) then
        write(*,'(f11.2,f12.4,a)') frac, elapsed, '   all CPU'
     else
        write(*,'(f11.2,f12.4)')   frac, elapsed
     end if
  end do

  write(*,'(a)') ' ------------------------------------------------------'
  write(*,'(a,f6.2,a,f10.4,a)') ' best split: ', best_frac, &
       ' of the work on the CPU, at ', best_time, ' s'
  write(*,'(a,f8.2,a)') ' vs all-GPU : ', t_gpu_only / max(best_time,1.0d-9), 'x'
  write(*,'(a,f8.2,a)') ' vs all-CPU : ', t_cpu_only / max(best_time,1.0d-9), 'x'
  write(*,'(a)') ''
  write(*,'(a)') ' How to read this:'
  write(*,'(a)') '  * best_frac at 0.00 or 1.00 -> one device dominates so'
  write(*,'(a)') '    completely that sharing is pointless. Use that device.'
  write(*,'(a)') '  * a shallow curve with a small interior minimum -> the'
  write(*,'(a)') '    split works but PCIe is eating most of the benefit.'
  write(*,'(a)') '  * predicted optimum is f = R_cpu / (R_cpu + R_gpu),'
  write(*,'(a)') '    i.e. f = t_gpu_only / (t_cpu_only + t_gpu_only).'
  write(*,'(a,f8.3)') '    predicted here: ', &
       t_gpu_only / max(t_cpu_only + t_gpu_only, 1.0d-9)
  write(*,'(a)') '  * measured worse than predicted? The difference is the'
  write(*,'(a)') '    synchronisation and transfer overhead you just paid for.'

  deallocate(spec, wind, sigma)

contains

  ! GPU slice. Runs asynchronously on queue 1; the caller continues.
  subroutine gpu_slice(sp, wd, sg, i0, i1, nsp, nsub_in, dt_in)
    integer, intent(in) :: i0, i1, nsp, nsub_in
    real,    intent(in) :: dt_in
    real, intent(inout) :: sp(nsp, *)
    real, intent(in)    :: wd(*), sg(nsp)
    integer :: ip, is, it
    real    :: x, sin_t, sds_t
    if (i0 > i1) return
    !$acc parallel loop gang async(1) present(sp, wd, sg) private(is, it, x, sin_t, sds_t)
    do ip = i0, i1
       !$acc loop vector
       do is = 1, nsp
          x = sp(is, ip)
          do it = 1, nsub_in
             sin_t = 1.2e-4 * wd(ip) * sg(is) * x
             sds_t = 2.6e-3 * sg(is) * x * sqrt(abs(x) + 1.0e-9)
             x = x + dt_in * (sin_t - sds_t)
             if (x < 0.0) x = 0.0
          end do
          sp(is, ip) = x
       end do
    end do
  end subroutine gpu_slice

  ! CPU slice. Plain OpenMP on the host copy.
  subroutine cpu_slice(sp, wd, sg, i0, i1, nsp, nsub_in, dt_in)
    integer, intent(in) :: i0, i1, nsp, nsub_in
    real,    intent(in) :: dt_in
    real, intent(inout) :: sp(nsp, *)
    real, intent(in)    :: wd(*), sg(nsp)
    integer :: ip, is, it
    real    :: x, sin_t, sds_t
    if (i0 > i1) return
    !$omp parallel do private(is, it, x, sin_t, sds_t) schedule(static)
    do ip = i0, i1
       do is = 1, nsp
          x = sp(is, ip)
          do it = 1, nsub_in
             sin_t = 1.2e-4 * wd(ip) * sg(is) * x
             sds_t = 2.6e-3 * sg(is) * x * sqrt(abs(x) + 1.0e-9)
             x = x + dt_in * (sin_t - sds_t)
             if (x < 0.0) x = 0.0
          end do
          sp(is, ip) = x
       end do
    end do
  end subroutine cpu_slice

  subroutine read_args(np, ns, nr)
    integer, intent(out) :: np, ns, nr
    character(len=32) :: arg
    np = 50000; ns = 8; nr = 10
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

  subroutine init(sp, wd, sg, np, nsp)
    integer, intent(in) :: np, nsp
    real, intent(out) :: sp(nsp, np), wd(np), sg(nsp)
    integer :: i, j
    real, parameter :: pi = 3.14159265358979
    do j = 1, nsp
       sg(j) = 2.0 * pi * 0.04118 * 1.1**real(mod(j - 1, 32))
    end do
    do i = 1, np
       wd(i) = 5.0 + 15.0 * real(mod(i, 101)) / 101.0
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

  subroutine toc(t0_in, dt_out)
    real(kind=8), intent(in)  :: t0_in
    real(kind=8), intent(out) :: dt_out
    integer(kind=8) :: c, cr
    call system_clock(c, cr)
    dt_out = real(c, 8) / real(cr, 8) - t0_in
  end subroutine toc

end program hetero_split
