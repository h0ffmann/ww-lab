#!/usr/bin/env python3
"""Turn a GEBCO (or any netCDF) bathymetry tile into WW3 ASCII grid files.

WW3's grid preprocessor doesn't read netCDF bathymetry -- you hand it plain
ASCII arrays and tell it the layout. This script does the regridding and
writes `bathy.inp` and `mask.inp` matching the RECT_NML block in
`ww3_grid.nml`.

Get the source data
-------------------
GEBCO 2024 grid, subsetted download for 52W-44W / 32S-24S:
    https://download.gebco.net/
Save as `gebco.nc` in this directory.

Any netCDF with (lat, lon, elevation) works. GEBCO's convention -- negative
below sea level -- is already WW3's convention, which is why `ww3_grid.nml`
sets DEPTH%SF = 1.

Usage
-----
    python make_bathy.py [gebco.nc]
"""

from __future__ import annotations

import sys

import numpy as np
import xarray as xr

# Must match &RECT_NML in ww3_grid.nml.
X0, Y0 = -52.0, -32.0
SX, SY = 0.1, 0.1
NX, NY = 81, 81

LAND, SEA, BOUNDARY = 0, 1, 2


def main() -> int:
    src = sys.argv[1] if len(sys.argv) > 1 else "gebco.nc"
    try:
        ds = xr.open_dataset(src)
    except (FileNotFoundError, OSError):
        print(f"could not open {src!r}. See the docstring for where to get it.",
              file=sys.stderr)
        return 1

    # GEBCO calls them lat/lon and elevation; be tolerant.
    latname = next(n for n in ("lat", "latitude", "y") if n in ds.coords)
    lonname = next(n for n in ("lon", "longitude", "x") if n in ds.coords)
    zname = next(n for n in ("elevation", "z", "Band1", "depth") if n in ds)

    lon = X0 + SX * np.arange(NX)
    lat = Y0 + SY * np.arange(NY)

    # Bilinear onto the model grid. For production work you would want
    # area-weighted averaging (conservative regridding) instead -- point
    # sampling a 15-arcsecond dataset onto a 0.1 degree grid throws away
    # most of the information and can miss a whole shoal.
    z = (ds[zname]
         .interp({lonname: xr.DataArray(lon, dims="x"),
                  latname: xr.DataArray(lat, dims="y")})
         .transpose("y", "x")
         .values)

    z = np.nan_to_num(z, nan=100.0)  # gaps -> treat as land, fail safe

    # IDLA = 1 means bottom row (j=1, southernmost) first, which is the
    # order lat is already in. Good.
    with open("bathy.inp", "w") as fh:
        for j in range(NY):
            fh.write(" ".join(f"{v:.1f}" for v in z[j]) + "\n")

    mask = np.where(z < -0.1, SEA, LAND).astype(int)

    # Mark the southern and eastern edges (one cell in) as open boundaries,
    # matching INBND_POINT in ww3_grid.nml. Only where they are wet.
    mask[1, 1:NX - 1] = np.where(mask[1, 1:NX - 1] == SEA, BOUNDARY, LAND)
    mask[1:NY - 1, NX - 2] = np.where(mask[1:NY - 1, NX - 2] == SEA, BOUNDARY, LAND)

    with open("mask.inp", "w") as fh:
        for j in range(NY):
            fh.write(" ".join(str(int(v)) for v in mask[j]) + "\n")

    n_sea = int((mask == SEA).sum())
    n_bnd = int((mask == BOUNDARY).sum())
    print(f"wrote bathy.inp and mask.inp  ({NX} x {NY})")
    print(f"  sea points      : {n_sea}")
    print(f"  boundary points : {n_bnd}")
    print(f"  land points     : {NX * NY - n_sea - n_bnd}")
    print(f"  depth range     : {z.min():.0f} to {z.max():.0f} m (negative = water)")
    if n_sea < 100:
        print("  !! suspiciously few sea points -- check your longitude convention")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
