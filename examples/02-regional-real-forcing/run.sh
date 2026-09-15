#!/usr/bin/env bash
# Example 02: regional run with real bathymetry and real winds.
# Unlike example 01, this one needs data you have to fetch yourself:
#   gebco.nc      from https://download.gebco.net/ (see make_bathy.F90)
#   gfs_winds.nc  from ./get_gfs.sh YYYYMMDD HH
# Run inside `just ww3` (gfortran, netcdf-fortran and nf-config are there).
#
# SPDX-License-Identifier: MIT
set -euo pipefail

cd "$(dirname "$0")"

if [ -n "${WW3:-}" ]; then
  for d in "$WW3/build/bin" "$WW3/build"; do [ -d "$d" ] && PATH="$d:$PATH"; done
  export PATH
fi
command -v ww3_grid >/dev/null || { echo "!! ww3_grid not on PATH; set \$WW3"; exit 1; }

[ -f gebco.nc ]     || { echo "!! missing gebco.nc -- see the header of make_bathy.F90"; exit 1; }
[ -f gfs_winds.nc ] || { echo "!! missing gfs_winds.nc -- run ./get_gfs.sh YYYYMMDD HH"; exit 1; }

echo "== bathymetry =================================================="
# Compiled here, against the toolchain's netcdf-fortran, when missing or stale.
if [ ! -x ./make_bathy ] || [ make_bathy.F90 -nt make_bathy ]; then
  command -v nf-config >/dev/null || { echo "!! nf-config not found -- run inside 'just ww3'"; exit 1; }
  # shellcheck disable=SC2046  # nf-config prints several flags; splitting is the point
  gfortran -O2 -std=f2018 -Wall -fimplicit-none $(nf-config --fflags) \
    -o make_bathy make_bathy.F90 $(nf-config --flibs)
fi
./make_bathy gebco.nc

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
  # what came out
  ncdump -h ww3.nc | head -60

  # Hs at the five points over time, as a table
  cdo -s outputtab,date,time,name,value -selname,hs ww3.nc | head -40

  # compare two runs field by field (e.g. boundaries on vs off)
  ../../kokkos/build/openmp-release/tools/nccmp-tol/nccmp-tol run_a/ww3.nc run_b/ww3.nc
NEXT
