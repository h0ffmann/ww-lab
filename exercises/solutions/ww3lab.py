#!/usr/bin/env python3
"""Reference solution for exercises 1-4, as a single reusable module.

Rather than six near-duplicate solution scripts, this is the thing you'd
actually end up writing: one module with the pipeline in it.

⚠ Written from the pyww3 documentation, not executed against a live WW3
build. Check keyword names against your installed version:
    python -c "from pyww3.grid import WW3Grid; help(WW3Grid)"

Deliberately, the homogeneous-forcing block is appended as raw text rather
than through pyww3 keywords -- that part of the wrapper is thin, and
knowing how to patch around it is the actual lesson.

Usage:
    from ww3lab import WW3Case
    ds = WW3Case("fetch", u10=10.0).run()
"""

from __future__ import annotations

import dataclasses
import hashlib
import json
import math
import pathlib
import shutil

import xarray as xr

try:
    from pyww3.grid import WW3Grid
except ImportError:  # some releases spell it WW3GRid
    from pyww3.grid import WW3GRid as WW3Grid
from pyww3.ounf import WW3Ounf
from pyww3.shel import WW3Shel

import datetime

G = 9.806
ROOT = pathlib.Path("runs").absolute()

# Namelist blocks pyww3 emits that a RECT/CART grid has no use for.
# ww3_grid objects to some of them, so strip them all.
UNUSED_GRID_BLOCKS = (
    "&CURV_NML",
    "&UNST_NML",
    "&SMC_NML",
    "&SED_NML",
    "&SLOPE_NML",
    "&OBST_NML",
)


def _floor_to(value: float, step: float) -> float:
    """Round DOWN to a multiple of step. Timestep limits are ceilings."""
    return math.floor(value / step) * step


@dataclasses.dataclass
class WW3Case:
    """One fetch-limited-growth configuration, start to finish."""

    name: str
    nx: int = 61
    ny: int = 5
    dx: float = 20_000.0          # metres
    depth: float = 250.0          # positive metres; flipped by DEPTH%SF = -1
    u10: float = 10.0             # m/s
    wind_dir: float = 270.0       # see the convention warning in examples/01
    hours: int = 48
    nk: int = 32
    nth: int = 24
    freq1: float = 0.04118
    xfr: float = 1.1

    # -- derived ------------------------------------------------------

    @property
    def fingerprint(self) -> str:
        blob = json.dumps(dataclasses.asdict(self), sort_keys=True)
        return hashlib.sha256(blob.encode()).hexdigest()[:12]

    @property
    def rundir(self) -> pathlib.Path:
        return ROOT / f"{self.name}-{self.fingerprint}"

    @property
    def cg_max(self) -> float:
        """Fastest deep-water group velocity = that of the lowest frequency."""
        return G / (4.0 * math.pi * self.freq1)

    @property
    def timesteps(self) -> dict[str, float]:
        t_cfl = self.dx / self.cg_max
        dtxy = _floor_to(0.9 * t_cfl, 10.0)
        dtmax = 3.0 * dtxy
        return {
            "dtmax": dtmax,
            "dtxy": dtxy,
            "dtkth": dtmax / 2.0,
            "dtmin": 10.0,
        }

    @property
    def start(self) -> datetime.datetime:
        return datetime.datetime(2020, 1, 1, 0)

    @property
    def stop(self) -> datetime.datetime:
        return self.start + datetime.timedelta(hours=self.hours)

    @staticmethod
    def _fmt(dt: datetime.datetime) -> str:
        return dt.strftime("%Y%m%d %H%M%S")

    # -- stages -------------------------------------------------------

    def write_inputs(self) -> None:
        run = self.rundir
        run.mkdir(parents=True, exist_ok=True)

        with open(run / "depth.inp", "w") as fh:
            for _ in range(self.ny):
                fh.write(" ".join(f"{self.depth:.1f}" for _ in range(self.nx)) + "\n")

        with open(run / "mask.inp", "w") as fh:
            for _ in range(self.ny):
                fh.write(" ".join(["0"] + ["1"] * (self.nx - 1)) + "\n")

        (run / "namelists.nml").write_text("&MISC\n  FLAGTR = 0\n/\n")
        (run / "config.json").write_text(
            json.dumps(dataclasses.asdict(self) | {"timesteps": self.timesteps}, indent=2)
        )

    def grid(self) -> None:
        ts = self.timesteps
        W = WW3Grid(
            runpath=str(self.rundir),
            grid_name=f"LAB {self.name}",
            grid_nml="namelists.nml",
            grid_type="RECT",
            grid_coord="CART",
            grid_clos="NONE",
            grid_zlim=-0.10,
            grid_dmin=2.50,
            spectrum_xfr=self.xfr,
            spectrum_freq1=self.freq1,
            spectrum_nk=self.nk,
            spectrum_nth=self.nth,
            run_flcx=True,
            run_flcy=True,
            run_flcth=True,
            run_flck=False,
            run_flsou=True,
            timesteps_dtmax=ts["dtmax"],
            timesteps_dtxy=ts["dtxy"],
            timesteps_dtkth=ts["dtkth"],
            timesteps_dtmin=ts["dtmin"],
            rect_nx=self.nx,
            rect_ny=self.ny,
            rect_sx=self.dx,
            rect_sy=self.dx,
            rect_sf=1.0,
            rect_x0=0.0,
            rect_y0=0.0,
            rect_sf0=1.0,
            depth_filename="depth.inp",
            depth_sf=-1.0,        # our file is positive depths
            depth_idla=1,
            mask_filename="mask.inp",
            mask_idla=1,
        )
        for block in UNUSED_GRID_BLOCKS:
            W.update_text(block, action="remove")
        W.to_file()
        W.run()
        if not (self.rundir / "mod_def.ww3").exists():
            raise RuntimeError(f"ww3_grid failed:\n{W.stdout}\n{W.stderr}")

    def shel(self) -> None:
        W = WW3Shel(
            nproc=1,
            runpath=str(self.rundir),
            mod_def=str(self.rundir / "mod_def.ww3"),
            domain_start=self.start,
            domain_stop=self.stop,
            input_forcing_winds=True,
            date_field_stride=3600,
            type_field_list=["HS", "T01", "T0M1", "FP", "DIR", "SPR", "WND", "DPT"],
        )
        # pyww3 does not expose &HOMOG_*_NML as keywords. Append by hand.
        W.text = W.text.rstrip() + f"""

&HOMOG_COUNT_NML
  HOMOG_COUNT%N_WND = 1
/

&HOMOG_INPUT_NML
  HOMOG_INPUT(1)%NAME   = 'WND'
  HOMOG_INPUT(1)%DATE   = '{self._fmt(self.start)}'
  HOMOG_INPUT(1)%VALUE1 = {self.u10}
  HOMOG_INPUT(1)%VALUE2 = {self.wind_dir}
  HOMOG_INPUT(1)%VALUE3 = 0.
/
"""
        W.to_file()
        W.run()
        if not (self.rundir / "out_grd.ww3").exists():
            raise RuntimeError(f"ww3_shel failed:\n{W.stdout}\n{W.stderr}")

    def ounf(self) -> None:
        W = WW3Ounf(
            runpath=str(self.rundir),
            mod_def=str(self.rundir / "mod_def.ww3"),
            field_timestart=self._fmt(self.start),
            field_timestride="3600",
            field_timestop=self._fmt(self.stop),
            field_timesplit=0,
            field_list="HS T01 T0M1 FP DIR SPR WND DPT",
            field_partition="0",
            field_type=4,
            file_prefix="ww3.",
            file_netcdf=4,
        )
        W.to_file()
        W.run()

    # -- driver -------------------------------------------------------

    def run(self, force: bool = False) -> xr.Dataset:
        existing = sorted(self.rundir.glob("ww3*.nc")) if self.rundir.exists() else []
        if existing and not force:
            return xr.open_dataset(existing[0])
        if force and self.rundir.exists():
            shutil.rmtree(self.rundir)
        self.write_inputs()
        self.grid()
        self.shel()
        self.ounf()
        out = sorted(self.rundir.glob("ww3*.nc"))
        if not out:
            raise RuntimeError(f"no netCDF produced in {self.rundir} -- is NC4 in your switch?")
        return xr.open_dataset(out[0])


# ---------------------------------------------------------------------
# Analysis helpers (exercise 3)
# ---------------------------------------------------------------------

def kahma_calkoen_hs(fetch_m, u10: float):
    """Hs from the Kahma & Calkoen (1992) fetch-limited growth law."""
    import numpy as np

    x_hat = G * np.asarray(fetch_m, dtype=float) / u10**2
    e_hat = 5.2e-7 * x_hat**0.9
    return 4.0 * np.sqrt(e_hat * u10**4 / G**2)


def pierson_moskowitz_hs(u10: float) -> float:
    """Fully developed limit. Steady-state Hs should approach, not exceed, this."""
    return 0.0246 * u10**2


def centre_row_hs(ds: xr.Dataset):
    """Hs along the centre row at the final time, plus the fetch axis in metres."""
    xname = "x" if "x" in ds.dims else "longitude"
    yname = "y" if "y" in ds.dims else "latitude"
    hs = ds["hs"].isel(time=-1)
    hs = hs.isel({yname: hs.sizes[yname] // 2})
    x = ds[xname].values.astype(float)
    return x - x.min(), hs.values


def sweep(speeds=(5.0, 7.5, 10.0, 12.5, 15.0, 20.0), **kwargs) -> xr.Dataset:
    """Exercise 4: run the case across wind speeds and concatenate."""
    parts = []
    for u in speeds:
        ds = WW3Case(f"sweep_u{u:g}", u10=u, **kwargs).run()
        parts.append(ds.expand_dims(u10=[u]))
    return xr.concat(parts, dim="u10")


if __name__ == "__main__":
    ds = WW3Case("demo").run()
    fetch, hs = centre_row_hs(ds)
    print(f"{'fetch [km]':>11} {'WW3 [m]':>9} {'K&C92 [m]':>10}")
    emp = kahma_calkoen_hs(fetch, 10.0)
    for i in range(1, len(fetch), 10):
        print(f"{fetch[i]/1000:11.0f} {hs[i]:9.3f} {emp[i]:10.3f}")
    print(f"\nPierson-Moskowitz limit at 10 m/s: {pierson_moskowitz_hs(10.0):.2f} m")
