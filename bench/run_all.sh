#!/usr/bin/env bash
# Run the whole benchmark suite and collect results.
#
# usage: run_all.sh [ww3-mpi-build-dir]
set -euo pipefail

WW3BUILD="${1:-${WW3:-}/build}"

echo "############################################################"
echo "# 1. Kernel proxy: CPU vs GPU on a WW3-shaped source term"
echo "############################################################"
if command -v nvfortran >/dev/null; then
  make kernel_cpu kernel_mc kernel_gpu hetero_split
  echo; echo "--- serial / OpenMP CPU (gfortran) ---"
  ./kernel_cpu
  echo; echo "--- OpenACC on CPU threads (nvfortran -acc=multicore) ---"
  ./kernel_mc
  echo; echo "--- OpenACC on GPU (nvfortran -acc -gpu=cc89) ---"
  NVCOMPILER_ACC_NOTIFY=1 ./kernel_gpu 2>&1 | tail -40
  echo; echo "--- heterogeneous split sweep: can they work together? ---"
  ./hetero_split
else
  echo "nvfortran not found; building the CPU variant only."
  echo "Install the NVIDIA HPC SDK for the GPU comparison:"
  echo "  https://developer.nvidia.com/hpc-sdk"
  make kernel_cpu && ./kernel_cpu
fi

echo
echo "############################################################"
echo "# 2. The real WW3, CPU scaling"
echo "############################################################"
if [ -d "$WW3BUILD" ]; then
  [ -d case_medium ] || python3 make_bench_case.py --size medium
  bash bench_ww3_cpu.sh "$WW3BUILD" case_medium
else
  echo "No WW3 build at '$WW3BUILD'."
  echo "Build one with the MPI switch first:"
  echo "  bash ../scripts/02_build_ww3.sh \$WW3 ../switches/switch_lab_mpi"
fi

echo
echo "Done. See RESULTS-TEMPLATE.md for how to write this up."
