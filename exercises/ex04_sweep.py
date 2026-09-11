#!/usr/bin/env python3
"""Exercise 4 — parameter sweep.

This is the actual reason to drive a model from Python. Editing eight
namelist files by hand to change one number is how mistakes happen; a loop
is how science happens.

Goal: run the fetch case across a grid of wind speeds and (optionally)
spectral resolutions, collect the results into a single xarray Dataset,
and plot the family of growth curves.
"""

from __future__ import annotations

import datetime
import itertools
import pathlib
import shutil

import xarray as xr

BASE = pathlib.Path("runs/sweep").absolute()

WIND_SPEEDS = [5.0, 7.5, 10.0, 12.5, 15.0, 20.0]
N_DIRECTIONS = [24]          # TODO: try [12, 24, 36] once winds work


def case_name(u10: float, nth: int) -> str:
    return f"u{u10:g}_nth{nth}"


def run_case(u10: float, nth: int) -> pathlib.Path:
    """Build, run, and post-process one configuration. Returns the run dir."""
    run = BASE / case_name(u10, nth)
    run.mkdir(parents=True, exist_ok=True)

    # ------------------------------------------------------------------
    # TODO 1. Reuse the helpers from ex01/ex02/ex03 -- import them rather
    # than copy-pasting. Refactor ex01's grid-file writer and the three
    # constructors into functions you can call with parameters.
    #
    # Skip work that's already done: if (run / "ww3.nc").exists() and is
    # newer than the namelists, return early. Sweeps get rerun constantly
    # and caching is the difference between a 2-minute and a 40-minute
    # iteration loop.
    # ------------------------------------------------------------------
    raise NotImplementedError("TODO")


def main() -> None:
    BASE.mkdir(parents=True, exist_ok=True)

    results = {}
    for u10, nth in itertools.product(WIND_SPEEDS, N_DIRECTIONS):
        print(f"=== {case_name(u10, nth)} ===")
        run = run_case(u10, nth)
        results[(u10, nth)] = xr.open_dataset(sorted(run.glob("ww3*.nc"))[0])

    # ------------------------------------------------------------------
    # TODO 2. Combine into one Dataset with u10 and nth as coordinates.
    #
    #   combined = xr.concat(
    #       [ds.expand_dims(u10=[u]) for (u, _), ds in results.items()],
    #       dim="u10",
    #   )
    #   combined.to_netcdf(BASE / "sweep.nc")
    # ------------------------------------------------------------------

    # ------------------------------------------------------------------
    # TODO 3. Two plots:
    #   (a) Hs vs fetch, one line per wind speed -- dimensional
    #   (b) e_hat vs x_hat, all speeds -- should collapse onto one curve
    #
    # Plot (b) is the payoff. If your curves collapse, your model obeys
    # the scaling. If one doesn't, find out why -- usually it hit the
    # fully-developed limit, or the domain is too short at that speed.
    # ------------------------------------------------------------------

    # ------------------------------------------------------------------
    # TODO 4 (stretch). Add a second axis to the sweep: build WW3 twice,
    # once with switch_lab_shrd (ST4) and once with switch_lab_st6 (ST6),
    # into separate build dirs, and sweep over the source-term package
    # too. Point PATH at the right build per case.
    #
    # The spread between ST4 and ST6 on the simplest problem in wave
    # modelling is a genuinely useful number to have personally measured.
    # ------------------------------------------------------------------


if __name__ == "__main__":
    main()
