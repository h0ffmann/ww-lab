#!/usr/bin/env bash
# Exercise 13 solution -- run the L2 replay on ww3_ts1 and read the table.
#
# usage: ex13_compare.sh <ww3-dir> [regtest=ww3_ts1]
#
# kokkos/tests/L2_replay.sh runs a regtest twice from the same work_lab --
# once with the Fortran W3SNL1 (WW_KOKKOS_SNL1=0) and once with the Kokkos
# kernel (WW_KOKKOS_SNL1=1) -- converts both with ww3_ounf and compares the
# fields with nccmp-tol, appending the table to kokkos/PORT_STATUS.md under
# "L2 replays". This script runs it, pulls that last table back out, and says
# in one line whether every judged field passed. Without the fork's PATCH
# applied to ww3_shel both runs take the Fortran path and the table proves the
# harness, not the kernel -- which is still the first thing to establish.
#
# Prerequisites (inside `just ww3`):
#   just rt <regtest>                  the work_lab this replays
#   just kokkos-build openmp-release   nccmp-tol
#
# Not executed in the environment this was written in (no WW3 checkout);
# bash -n and shellcheck clean.
#
# SPDX-License-Identifier: MIT
set -euo pipefail

WW3DIR="${1:?usage: ex13_compare.sh <ww3-dir> [regtest]}"
TEST="${2:-ww3_ts1}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REPLAY="$ROOT/kokkos/tests/L2_replay.sh"
STATUS="$ROOT/kokkos/PORT_STATUS.md"
OUT="$ROOT/exercises/solutions/out/ex13"
mkdir -p "$OUT"

[ -x "$REPLAY" ] || [ -f "$REPLAY" ] || {
  echo "!! $REPLAY not found -- it arrives with the nccmp-tol/L2 tooling (kokkos/tools/nccmp-tol)"
  exit 1
}
[ -d "$WW3DIR/regtests/$TEST/work_lab" ] || { echo "!! no work_lab for $TEST -- run: just rt $TEST"; exit 1; }

echo "############ L2 replay of $TEST"
bash "$REPLAY" "$WW3DIR" "$TEST" 2>&1 | tee "$OUT/replay.log"

[ -f "$STATUS" ] || { echo "!! $STATUS was not written -- see $OUT/replay.log"; exit 1; }

# The table the replay just appended: everything after the last "L2 replays"
# heading in PORT_STATUS.md.
awk 'tolower($0) ~ /^#+ *l2 replays/ { buf = "" } { buf = buf $0 "\n" } END { printf "%s", buf }' \
  "$STATUS" > "$OUT/l2_table.md"

echo
echo "############ what PORT_STATUS.md now says"
cat "$OUT/l2_table.md"

# One-line verdict: nccmp-tol prints pass/FAIL per judged variable (see
# kokkos/tools/nccmp-tol/README.md); count them in the section we just cut out.
n_pass=$(grep -ciE '(^|[| ])pass([| ]|$)' "$OUT/l2_table.md" || true)
n_fail=$(grep -ciE '(^|[| ])fail([| ]|$)' "$OUT/l2_table.md" || true)
echo
if [ "$n_fail" -eq 0 ] && [ "$n_pass" -gt 0 ]; then
  echo "ex13: $n_pass judged field(s) inside tolerance, none outside -- parity holds for $TEST"
elif [ "$n_fail" -gt 0 ]; then
  echo "ex13: $n_fail judged field(s) OUTSIDE tolerance ($n_pass inside) -- read the max_rel column and lesson 12's tolerance discussion"
else
  echo "ex13: could not find pass/fail verdicts in the table -- read $OUT/l2_table.md by hand"
fi
