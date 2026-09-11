#!/usr/bin/env bash
# Example 02: regional run with real bathymetry and real winds.
# Unlike example 01, this one needs data you have to fetch yourself.
set -euo pipefail

if [ -n "${WW3:-}" ]; then
  for d in "$WW3/build/bin" "$WW3/build"; do [ -d "$d" ] && PATH="$d:$PATH"; done
  export PATH
fi
command -v ww3_grid >/dev/null || { echo "!! ww3_grid not on PATH; set \$WW3"; exit 1; }

[ -f gebco.nc ]      || { echo "!! missing gebco.nc -- see make_bathy.py docstring"; exit 1; }
[ -f era5_winds.nc ] || { echo "!! missing era5_winds.nc -- run get_era5.py"; exit 1; }

echo "== bathymetry =================================================="
python3 make_bathy.py gebco.nc

echo; echo "== ww3_grid ===================================================="
ww3_grid | tee ww3_grid.out

echo; echo "== ww3_prnc (winds) ============================================"
cp ww3_prnc_wind.nml ww3_prnc.nml
ww3_prnc | tee ww3_prnc_wind.out

echo; echo "== ww3_shel ===================================================="
# Serial. For the MPI build:  mpirun -np $(nproc) ww3_shel
ww3_shel | tee ww3_shel.out

echo; echo "== ww3_ounf / ww3_ounp ========================================="
ww3_ounf | tee ww3_ounf.out
ww3_ounp | tee ww3_ounp.out

ls -la ./*.nc
cat <<'NEXT'

Next:
  # gridded fields
  python3 -c "import xarray as xr; print(xr.open_dataset('ww3.nc'))"

  # spectra at the five points, via wavespectra
  python3 - <<'PY'
  from wavespectra import read_ww3
  ds = read_ww3('ww3.<spec-file>.nc')
  print(ds.spec.stats(['hs','tp','dpm']))
  ds.isel(time=0, site=0).spec.plot(kind='contourf')
  PY
NEXT
