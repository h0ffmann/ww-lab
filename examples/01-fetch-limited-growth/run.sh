#!/usr/bin/env bash
# Run ww3-lab example 01 end to end.
#
# Expects WW3 executables on PATH, or $WW3 pointing at your clone. The grid
# inputs come from make_inputs.F90 (compiled here with gfortran if needed); the
# analysis at the end uses ww_fetch_analyse from the kokkos/ tree
# (`just kokkos-build openmp-release`, or set WW_FETCH_ANALYSE).
#
# SPDX-License-Identifier: MIT
set -euo pipefail

cd "$(dirname "$0")"

if [ -n "${WW3:-}" ]; then
  for d in "$WW3/build/bin" "$WW3/build"; do
    [ -d "$d" ] && PATH="$d:$PATH"
  done
  export PATH
fi

command -v ww3_grid >/dev/null || {
  echo "!! ww3_grid not on PATH."
  echo "   export WW3=/path/to/your/WW3   (see ../../scripts/02_build_ww3.sh)"
  exit 1
}

FETCH_ANALYSE="${WW_FETCH_ANALYSE:-../../kokkos/build/openmp-release/tools/fetch_analyse/ww_fetch_analyse}"

echo "== generating ASCII bathymetry + mask =========================="
# Rebuilt only when the source is newer than the binary, so re-running after
# editing NX/NY/DEPTH_M picks the change up and re-running unchanged is free.
if [ ! -x ./make_inputs ] || [ make_inputs.F90 -nt make_inputs ]; then
  gfortran -O2 -std=f2018 -Wall -fimplicit-none -o make_inputs make_inputs.F90
fi
./make_inputs

echo
echo "== ww3_grid : inputs -> mod_def.ww3 ============================"
# mod_def.ww3 is an opaque binary holding the ENTIRE model definition:
# grid, spectrum, timesteps, physics switches, masks. Every other program
# reads it. If you change ww3_grid.nml you must rerun this, and everything
# downstream becomes stale.
ww3_grid | tee ww3_grid.out

echo
echo "== ww3_shel : run the model ===================================="
# No restart.ww3 present, so this is a cold start from a calm sea. WW3 says
# so in the log. If you want an explicit initial spectrum instead, run
# ww3_strt first -- copy an ww3_strt.nml from $WW3/regtests/*/input/.
ww3_shel | tee ww3_shel.out

echo
echo "== ww3_ounf : out_grd.ww3 -> netCDF ============================"
ww3_ounf | tee ww3_ounf.out

echo
echo "== results ====================================================="
ls -la ./*.nc
echo

# TIMESPLIT = 0 in ww3_ounf.nml gives a single ww3.nc; anything else dates the
# name, so take whatever ww3_ounf produced.
NC=$(find . -maxdepth 1 -name 'ww3*.nc' | sort | head -n 1)
if [ -x "$FETCH_ANALYSE" ]; then
  echo "== fetch-growth check: WW3 vs Kahma & Calkoen 1992 =============="
  "$FETCH_ANALYSE" "$NC"
else
  echo "ww_fetch_analyse not built at $FETCH_ANALYSE"
  echo "Build it:   just kokkos-build openmp-release      (from the repo root)"
  echo "Then:       $FETCH_ANALYSE $NC"
fi
