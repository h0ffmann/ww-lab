# ww3-lab benchmark suite
#
#   make            build everything available
#   make cpu        CPU-only targets (gfortran; no NVIDIA SDK needed)
#   make run        build and run the kernel benchmarks
#   make case       generate the medium WW3 benchmark case
#   make clean
#
# Override the GPU target for non-Ada cards:  make CC_ARCH=cc80

FC_GNU  ?= gfortran
FC_NV   ?= nvfortran
CC_ARCH ?= cc89
OPT     ?= -O3

.PHONY: all cpu run case clean

all: kernel_cpu kernel_mc kernel_gpu hetero_split

cpu: kernel_cpu

# Plain host build. OpenACC directives are comments to gfortran, so this
# is the pure-OpenMP reference point.
kernel_cpu: kernel_bench.f90
	$(FC_GNU) $(OPT) -fopenmp -o $@ $<

# Same directives, nvfortran, CPU threads. The correctness reference for
# the GPU build -- if these two disagree, it is a data-movement bug.
kernel_mc: kernel_bench.f90
	$(FC_NV) $(OPT) -acc=multicore -mp -o $@ $<

kernel_gpu: kernel_bench.f90
	$(FC_NV) $(OPT) -acc -gpu=$(CC_ARCH) -mp -Minfo=accel -o $@ $<

# Needs both -acc and -mp: the GPU kernel runs async while OpenMP threads
# work on the host slice.
hetero_split: hetero_split.f90
	$(FC_NV) $(OPT) -acc -gpu=$(CC_ARCH) -mp -Minfo=accel -o $@ $<

case:
	python3 make_bench_case.py --size medium

run: all
	@echo "=== kernel_cpu (gfortran, OpenMP) ==="; ./kernel_cpu
	@echo; echo "=== kernel_mc (nvfortran, -acc=multicore) ==="; ./kernel_mc
	@echo; echo "=== kernel_gpu (nvfortran, -acc, $(CC_ARCH)) ==="; ./kernel_gpu
	@echo; echo "=== hetero_split (CPU + GPU concurrently) ==="; ./hetero_split

clean:
	rm -f kernel_cpu kernel_mc kernel_gpu hetero_split *.mod *.o
	rm -rf run_np* case_small case_medium case_large results_*.csv
