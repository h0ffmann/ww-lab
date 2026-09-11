#!/usr/bin/env bash
# Run ww3-lab example 01 end to end.
#
# Expects WW3 executables on PATH, or $WW3 pointing at your clone.
set -euo pipefail

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

echo "== generating ASCII bathymetry + mask =========================="
python3 make_inputs.py

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
echo "Now:  python3 analyse.py ww3.nc"
echo "(the exact filename depends on TIMESPLIT; ls above shows what you got)"
