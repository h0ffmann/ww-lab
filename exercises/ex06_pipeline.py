#!/usr/bin/env python3
"""Exercise 6 — build the tool you'd actually use.

Everything so far has been scripts. This exercise turns it into a small
reusable class. That's the real deliverable of learning pyww3: not pyww3
itself, but the understanding that lets you write 200 lines that fit your
workflow exactly.

Goal: a WW3Case class where

    case = WW3Case("my_run", nx=61, ny=5, dx=20000, u10=10.0)
    ds = case.run()          # idempotent, cached, returns an xarray Dataset

does the whole pipeline.
"""

from __future__ import annotations

import dataclasses
import hashlib
import json
import pathlib
import shutil
import subprocess

import xarray as xr

ROOT = pathlib.Path("runs").absolute()


@dataclasses.dataclass
class WW3Case:
    """One WW3 configuration, start to finish."""

    name: str
    nx: int = 61
    ny: int = 5
    dx: float = 20000.0
    depth: float = 250.0
    u10: float = 10.0
    wind_dir: float = 270.0
    hours: int = 48
    nk: int = 32
    nth: int = 24
    freq1: float = 0.04118

    # ------------------------------------------------------------------
    # TODO 1. A content hash of the configuration. This is what makes
    # caching safe: if any parameter changes, the hash changes, and you
    # rerun. If nothing changed, you reuse.
    #
    #   @property
    #   def fingerprint(self) -> str:
    #       blob = json.dumps(dataclasses.asdict(self), sort_keys=True)
    #       return hashlib.sha256(blob.encode()).hexdigest()[:12]
    #
    #   @property
    #   def rundir(self) -> pathlib.Path:
    #       return ROOT / f"{self.name}-{self.fingerprint}"
    # ------------------------------------------------------------------

    # ------------------------------------------------------------------
    # TODO 2. Derive the timesteps rather than hardcoding them. This is
    # the bit that makes the class genuinely useful -- you change dx and
    # the CFL numbers follow.
    #
    #   cg_max = 9.806 / (4 * pi * self.freq1)
    #   t_cfl  = self.dx / cg_max
    #   dtxy   = floor(0.9 * t_cfl / 10) * 10     # round DOWN to 10 s
    #   dtmax  = 3 * dtxy
    #   dtkth  = dtmax / 2
    #   dtmin  = 10.
    #
    # Expose these as properties so a caller can inspect them before
    # committing to an expensive run.
    # ------------------------------------------------------------------

    # ------------------------------------------------------------------
    # TODO 3. Methods: write_inputs(), grid(), shel(), ounf(), and a
    # run() that chains them with caching:
    #
    #   def run(self, force: bool = False) -> xr.Dataset:
    #       out = self.rundir / "ww3.nc"
    #       if out.exists() and not force:
    #           return xr.open_dataset(out)
    #       self.write_inputs(); self.grid(); self.shel(); self.ounf()
    #       return xr.open_dataset(sorted(self.rundir.glob("ww3*.nc"))[0])
    #
    # Write the config JSON into the run dir too. Six months from now you
    # will be looking at a directory full of netCDF files trying to
    # remember what each one was.
    # ------------------------------------------------------------------

    # ------------------------------------------------------------------
    # TODO 4. Decide: pyww3, or your own Jinja2 templates?
    #
    # Try both. pyww3 gives you validation and typed keywords for free but
    # you fight it on &HOMOG_INPUT_NML. Templates give you total control
    # and take an afternoon.
    #
    # Whichever you pick, the point is that YOU now know what a valid
    # namelist looks like, which is the thing the exercises were for.
    # ------------------------------------------------------------------


def main() -> None:
    cases = [WW3Case("fetch", u10=u) for u in (5.0, 10.0, 15.0, 20.0)]
    for c in cases:
        print(c.name, dataclasses.asdict(c))
        # ds = c.run()
    # ------------------------------------------------------------------
    # TODO 5 (stretch). Parallelise across cases with
    # concurrent.futures.ProcessPoolExecutor. WW3 runs are independent, so
    # four serial runs on four cores beats one MPI run on four cores for
    # a sweep -- no communication, perfect scaling. Worth knowing before
    # you go looking for a GPU.
    # ------------------------------------------------------------------


if __name__ == "__main__":
    main()
