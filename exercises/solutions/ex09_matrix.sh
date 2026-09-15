#!/usr/bin/env bash
# Exercise 09 solution -- the compile-option matrix.
#
# usage: ex09_matrix.sh <ww3-dir> [regtest=ww3_tp1.1]
#
# Builds WW3 twice from switches/switch_lab_shrd with OMPG added (OpenMP
# threads do nothing without it), once with -O2 and once with -O3
# -march=native; runs <regtest>'s ww3_shel with 1, 2 and 4 threads for each
# build; tabulates wall-clock seconds and the nccmp-tol verdict against the
# reference output that `just rt <regtest>` left in work_lab/. Everything
# lands in exercises/solutions/out/ex09/.
#
# Prerequisites (inside `just ww3`):
#   just rt <regtest>                  the reference run (its ww3*.nc is what we compare to)
#   just kokkos-build openmp-release   for nccmp-tol (verdict column says "n/a" without it)
#
# How the flags reach the build: CMake seeds CMAKE_Fortran_FLAGS from $FFLAGS on a
# fresh configure, and scripts/02_build_ww3.sh always configures fresh. WW3's own
# CMake appends the build-type flags after them, so the build type is passed as
# "None" here to keep -O3 from CMAKE_Fortran_FLAGS_RELEASE out of the way -- check
# `grep -n "O3\|Fortran_FLAGS" <ww3-dir>/model/CMakeLists.txt <ww3-dir>/cmake/*` if
# your WW3 revision behaves differently.
#
# Not executed in the environment this was written in (no WW3 checkout);
# bash -n and shellcheck clean.
#
# SPDX-License-Identifier: MIT
set -euo pipefail

WW3DIR="${1:?usage: ex09_matrix.sh <ww3-dir> [regtest]}"
TEST="${2:-ww3_tp1.1}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/exercises/solutions/out/ex09"
NCCMP="${NCCMP_TOL:-$ROOT/kokkos/build/openmp-release/tools/nccmp-tol/nccmp-tol}"
WORK="$WW3DIR/regtests/$TEST/work_lab"
THREADS=(1 2 4)

[ -d "$WORK" ] || { echo "!! no $WORK -- run: just rt $TEST"; exit 1; }
mkdir -p "$OUT"

# The reference field file from `just rt`. ww3_ounf names it ww3.<date>.nc or ww3.nc.
REF=$(find "$WORK" -maxdepth 1 -name 'ww3*.nc' | sort | head -n 1)
[ -n "$REF" ] || { echo "!! no ww3*.nc in $WORK -- did the reference run finish?"; exit 1; }
cp "$REF" "$OUT/reference.nc"

# switch_lab_shrd + OMPG: shared-memory build with OpenMP directives compiled in.
SWITCH="$OUT/switch_lab_omp"
sed 's/\bSHRD\b/SHRD OMPG/' "$ROOT/switches/switch_lab_shrd" > "$SWITCH"

TABLE="$OUT/matrix.md"
{
  echo "# ex09: compile-option matrix, $TEST"
  echo
  echo "reference: $REF"
  echo
  echo "| flags | threads | wall s (ww3_shel) | nccmp-tol vs reference |"
  echo "|---|---|---|---|"
} > "$TABLE"

now() { date +%s.%N; }

for FLAGS in "-O2" "-O3 -march=native"; do
  echo "############ building with FFLAGS='$FLAGS'"
  FFLAGS="$FLAGS" bash "$ROOT/scripts/02_build_ww3.sh" "$WW3DIR" "$SWITCH" None > "$OUT/build_${FLAGS// /_}.log" 2>&1
  # One full pass of the regtest pipeline sets up work_lab with this build's
  # binaries and mod_def; then only ww3_shel (+ ww3_ounf for the file) is retimed.
  bash "$ROOT/scripts/03_run_regtest.sh" "$WW3DIR" "$TEST" > "$OUT/regtest_${FLAGS// /_}.log" 2>&1
  for n in "${THREADS[@]}"; do
    (
      cd "$WORK"
      rm -f ww3*.nc
      t0=$(now)
      OMP_NUM_THREADS="$n" OMP_PROC_BIND=true ./ww3_shel > "ww3_shel_${n}.out" 2>&1
      t1=$(now)
      ./ww3_ounf > "ww3_ounf_${n}.out" 2>&1
      wall=$(awk -v a="$t0" -v b="$t1" 'BEGIN { printf "%.2f", b - a }')
      got=$(find . -maxdepth 1 -name 'ww3*.nc' | sort | head -n 1)
      if [ -x "$NCCMP" ] && [ -n "$got" ]; then
        if "$NCCMP" "$OUT/reference.nc" "$got" > "$OUT/nccmp_${FLAGS// /_}_${n}.txt" 2>&1; then
          verdict="pass"
        else
          verdict="FAIL (see nccmp_${FLAGS// /_}_${n}.txt)"
        fi
      else
        verdict="n/a"
      fi
      printf "| \`%s\` | %d | %s | %s |\n" "$FLAGS" "$n" "$wall" "$verdict" >> "$TABLE"
      printf '%-20s %d threads  %8s s  %s\n' "$FLAGS" "$n" "$wall" "$verdict"
    )
  done
done

cat "$TABLE"
cat <<'NOTE'

Reading it
----------
* -O3 -march=native vs -O2 is usually a few percent on WW3; if it is more, look
  at which routines vectorised (-fopt-info-vec) before believing it.
* Threads only help where the switch has OMPG *and* the loops are threaded --
  ww3_tp1.1 is propagation only and small, so expect little; try ww3_ts1.
* A "FAIL" from nccmp-tol with -march=native or with threads is not necessarily
  a bug: FMA contraction and reduction order both change the last bits. The
  question lesson 09 asks is whether the difference is inside the tolerance
  table, and if not, whether you can explain it.
NOTE
