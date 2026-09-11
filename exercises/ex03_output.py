#!/usr/bin/env python3
"""Exercise 3 — netCDF output, and check the physics.

Depends on: ex02 having produced runs/ex02/out_grd.ww3.

Goal: convert to netCDF with ww3_ounf, load with xarray, and verify the
fetch-limited growth against the Kahma & Calkoen (1992) law. This is where
you find out whether your build does physics.
"""

from __future__ import annotations

import pathlib

import numpy as np
import xarray as xr
from pyww3.ounf import WW3Ounf

RUN = pathlib.Path("runs/ex02").absolute()
G = 9.806
U10 = 10.0


def main() -> None:
    # ------------------------------------------------------------------
    # TODO 1. Construct and run WW3Ounf.
    #
    #   field_timestart  = '20200101 000000'
    #   field_timestride = '3600'
    #   field_timesplit  = 0          (single file, no date in the name)
    #   field_list       = 'HS T01 T0M1 FP DIR SPR WND DPT'
    #   field_type       = 4          (REAL, not packed)
    #   file_netcdf      = 4
    #
    # Check the exact keyword names against
    #   python -c "from pyww3.ounf import WW3Ounf; help(WW3Ounf)"
    # or the API docs at https://pyww3.readthedocs.io/en/latest/API.html
    # ------------------------------------------------------------------
    W = WW3Ounf(runpath=str(RUN), mod_def=str(RUN / "mod_def.ww3"))
    # ... TODO
    W.to_file()
    W.run()
    print(W.stdout)

    # ------------------------------------------------------------------
    # TODO 2. Find and open the netCDF file. The name depends on
    # TIMESPLIT; just glob for it.
    #
    #   nc = sorted(RUN.glob("ww3*.nc"))[0]
    #   ds = xr.open_dataset(nc)
    #   print(ds)
    # ------------------------------------------------------------------

    # ------------------------------------------------------------------
    # TODO 3. Extract Hs along the centre row at the final time and plot
    # it against fetch.
    #
    # ⚠ First: does Hs INCREASE with x? If it decreases, the wind
    # direction convention is the other way round -- go back to ex02 and
    # use VALUE2 = 90. This is a real ambiguity and resolving it on your
    # own build is the point of the exercise.
    # ------------------------------------------------------------------

    # ------------------------------------------------------------------
    # TODO 4. Compare against Kahma & Calkoen (1992):
    #
    #   x_hat = G * fetch / U10**2                  (dimensionless fetch)
    #   e_hat = 5.2e-7 * x_hat**0.9                 (dimensionless energy)
    #   E     = e_hat * U10**4 / G**2
    #   Hs    = 4 * sqrt(E)
    #
    # And the fully developed limit (Pierson-Moskowitz):
    #   Hs_max = 0.0246 * U10**2                    (= 2.46 m at 10 m/s)
    #
    # Plot all three. You should land within a few tens of percent over
    # the growing part of the fetch, converging towards the PM limit.
    # ------------------------------------------------------------------

    # ------------------------------------------------------------------
    # TODO 5. Repeat with U10 = 5, 15, 20 m/s (rerun ex02 each time) and
    # confirm the results collapse onto one curve in dimensionless
    # coordinates (x_hat, e_hat). That collapse IS the scaling law, and
    # seeing your own model reproduce it is the moment WW3 stops being a
    # black box.
    # ------------------------------------------------------------------


if __name__ == "__main__":
    main()
