! Smallest possible "is my toolchain real" test.
!
!   nvfortran -acc -gpu=cc89 -Minfo=accel -o 00_hello_acc 00_hello_acc.f90
!   NVCOMPILER_ACC_NOTIFY=1 ./00_hello_acc
!
! If NVCOMPILER_ACC_NOTIFY prints a "launch CUDA kernel" line, you are
! genuinely running on the GPU. If it prints nothing, you compiled a CPU
! binary and everything downstream will be a lie.
!
! Read the -Minfo=accel output. It tells you which loops were offloaded
! and, when they weren't, exactly why. That output is the single most
! useful thing about OpenACC development.

program hello_acc
  implicit none
  integer, parameter :: n = 50000000
  real, allocatable :: a(:), b(:)
  real :: s
  integer :: i

  allocate(a(n), b(n))

  !$acc data create(a, b)

  !$acc parallel loop
  do i = 1, n
     a(i) = real(i)
     b(i) = 2.0 * real(i)
  end do

  s = 0.0
  !$acc parallel loop reduction(+:s)
  do i = 1, n
     s = s + a(i) * b(i)
  end do

  !$acc end data

  print '(a,es16.8)', ' sum of a*b = ', s
  print '(a,es16.8)', ' expected   = ', 2.0 * real(n) * real(n+1) * real(2*n+1) / 6.0
  print *, '(single precision: expect visible rounding error at this n --'
  print *, ' that is the point. See 03_precision.f90.)'

  deallocate(a, b)
end program hello_acc
