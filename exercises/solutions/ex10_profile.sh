#!/usr/bin/env bash
# Exercise 10 solution -- a gprof profile of ww3_shel, bucketed by phase.
#
# usage: ex10_profile.sh <ww3-dir> [regtest=ww3_ts1]
#
# Rebuilds WW3 with -pg (switches/switch_lab_shrd), runs <regtest> once to set
# the work directory up, then runs ww3_shel ALONE so its gmon.out is not
# overwritten by ww3_ounf's, and turns `gprof -b -p` (the flat profile) into
# two tables in exercises/solutions/out/ex10/:
#   profile.md   the top 25 routines: self %, cumulative %, phase
#   phases.md    self % summed per phase
# The phase buckets are the ones lesson 09 uses:
#   w3srce*, w3sin*, w3sds*, w3snl*, w3sbt*   -> source terms
#   w3pro*, w3uqck*, w3prop*                  -> propagation
#   w3gath, w3scat, mpi_*, w3xdat*            -> communication
#   w3io*, w3fld*, w3nml*                     -> I/O
#   everything else                           -> other
# kokkos/tools/profile/gprof_table.sh is the maintained version of the same
# idea; this one is self-contained so the exercise does not depend on it.
#
# Not executed in the environment this was written in (no WW3 checkout);
# bash -n and shellcheck clean.
#
# SPDX-License-Identifier: MIT
set -euo pipefail

WW3DIR="${1:?usage: ex10_profile.sh <ww3-dir> [regtest]}"
TEST="${2:-ww3_ts1}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/exercises/solutions/out/ex10"
WORK="$WW3DIR/regtests/$TEST/work_lab"
mkdir -p "$OUT"

command -v gprof >/dev/null || { echo "!! gprof not found (binutils) -- run inside 'just ww3'"; exit 1; }

echo "############ building with -pg"
# -pg must reach both the compile and the link; CMake seeds CMAKE_Fortran_FLAGS
# from FFLAGS and CMAKE_EXE_LINKER_FLAGS from LDFLAGS on a fresh configure.
FFLAGS="-pg" LDFLAGS="-pg" bash "$ROOT/scripts/02_build_ww3.sh" "$WW3DIR" \
  "$ROOT/switches/switch_lab_shrd" Release > "$OUT/build.log" 2>&1

echo "############ $TEST: one full pass, then ww3_shel alone for the profile"
bash "$ROOT/scripts/03_run_regtest.sh" "$WW3DIR" "$TEST" > "$OUT/regtest.log" 2>&1
(
  cd "$WORK"
  rm -f gmon.out
  ./ww3_shel > ww3_shel_profiled.out 2>&1
  [ -f gmon.out ] || { echo "!! no gmon.out -- did -pg reach the link? see $OUT/build.log"; exit 1; }
  gprof -b -p ./ww3_shel gmon.out > "$OUT/gprof_flat.txt"
)

# gprof's flat profile: "%time  cumulative-s  self-s  calls  self-ms/call  total-ms/call  name".
# Routines are the Fortran names as the linker sees them (module_MOD_routine for
# gfortran); the bucket is decided on the routine part.
phase_of() {
  local n="$1"
  case "$n" in
    w3srce*|w3sin*|w3sds*|w3snl*|w3sbt*|w3sdb*|w3str*|w3sbs*|w3sic*|w3sis*|w3ref*) echo "source terms" ;;
    w3pro*|w3uqck*|w3uno*|w3ktp*|w3xyp*|w3cspc*)                                 echo "propagation" ;;
    w3gath*|w3scat*|mpi_*|w3xdat*|w3wave_data*|w3mpi*)                             echo "communication" ;;
    w3io*|w3fld*|w3nml*|w3out*|w3wdat*|w3updt*)                                    echo "I/O" ;;
    *)                                                                              echo "other" ;;
  esac
}

{
  echo "# ex10: gprof flat profile of ww3_shel, $TEST"
  echo
  echo "| routine | self % | cumulative % | phase |"
  echo "|---|---|---|---|"
} > "$OUT/profile.md"
: > "$OUT/phases.tsv"

cum=0
awk 'f && NF >= 7 && $1 ~ /^[0-9.]+$/ { print $1, $NF } /^ *%/ { f = 1 }' "$OUT/gprof_flat.txt" \
  | head -n 25 \
  | while read -r pct name; do
      # __w3srcemd_MOD_w3srce -> w3srce ; plain C/Fortran names pass through
      routine="${name##*_MOD_}"; routine="${routine#__}"; routine="${routine%_}"
      phase=$(phase_of "$routine")
      cum=$(awk -v a="$cum" -v b="$pct" 'BEGIN { printf "%.2f", a + b }')
      printf "| \`%s\` | %s | %s | %s |\n" "$routine" "$pct" "$cum" "$phase" >> "$OUT/profile.md"
      printf '%s\t%s\n' "$phase" "$pct" >> "$OUT/phases.tsv"
    done

{
  echo "# ex10: self % per phase (top 25 routines), $TEST"
  echo
  echo "| phase | self % |"
  echo "|---|---|"
  awk -F'\t' '{ s[$1] += $2 } END { for (p in s) printf "| %s | %.1f |\n", p, s[p] }' "$OUT/phases.tsv" \
    | sort -t'|' -k3 -rn
} > "$OUT/phases.md"

cat "$OUT/profile.md"; echo; cat "$OUT/phases.md"
cat <<'NOTE'

Reading it
----------
* The phase with the largest share is where a port pays. On ww3_ts1 (source
  terms in isolation) that is the source-term bucket by construction; on a
  propagation test it will not be. Profile the case you care about.
* gprof samples at 100 Hz and attributes time by function; inlined routines
  vanish into their caller. If a big "other" appears, look at which module the
  names came from (the _MOD_ prefix in gprof_flat.txt) before trusting it.
* `perf` is not in the pratico shell; kokkos/tools/profile/perf_table.sh is the
  same table from perf where it exists.
NOTE
