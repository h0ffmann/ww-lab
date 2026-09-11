#!/usr/bin/env python3
"""Generate a WW3 benchmark case of a chosen size.

Writes a complete, self-contained run directory (namelists + ASCII
bathymetry + mask) sized so that a serial run takes long enough to
measure but short enough to iterate on. No external data needed.

The timesteps are DERIVED from the grid spacing via the CFL condition,
so changing the size keeps the case physically valid instead of silently
unstable. That matters for a benchmark: an unstable run and a stable run
do different amounts of work.

Usage:
    python3 make_bench_case.py            # medium, ~1-2 min serial
    python3 make_bench_case.py --size small
    python3 make_bench_case.py --size large --hours 48
    python3 make_bench_case.py --nx 600 --ny 400 --nth 48
"""

from __future__ import annotations

import argparse
import datetime
import json
import math
import pathlib

G = 9.806
FREQ1 = 0.04118

# nx, ny, nk, nth, hours -- chosen so serial runtimes land roughly at
# 10 s / 90 s / 15 min on a modern desktop core. Very rough.
SIZES = {
    "small":  dict(nx=120, ny=80,  nk=24, nth=24, hours=12),
    "medium": dict(nx=300, ny=200, nk=32, nth=36, hours=24),
    "large":  dict(nx=700, ny=450, nk=32, nth=36, hours=48),
}


def timesteps(dx_m: float) -> dict[str, float]:
    """CFL-derived timesteps. Rounded DOWN -- these are ceilings."""
    cg_max = G / (4.0 * math.pi * FREQ1)
    t_cfl = dx_m / cg_max
    dtxy = max(10.0, math.floor(0.9 * t_cfl / 10.0) * 10.0)
    dtmax = 3.0 * dtxy
    return dict(dtmax=dtmax, dtxy=dtxy, dtkth=dtmax / 2.0, dtmin=10.0)


def write_case(out: pathlib.Path, nx, ny, nk, nth, hours, dx_m) -> None:
    out.mkdir(parents=True, exist_ok=True)
    ts = timesteps(dx_m)

    # Flat deep basin with land along the west edge. Same physics as
    # examples/01, just big enough to be worth parallelising.
    with open(out / "depth.inp", "w") as fh:
        for _ in range(ny):
            fh.write(" ".join(["500.0"] * nx) + "\n")
    with open(out / "mask.inp", "w") as fh:
        for _ in range(ny):
            fh.write(" ".join(["0"] + ["1"] * (nx - 1)) + "\n")

    (out / "namelists.nml").write_text("&MISC\n  FLAGTR = 0\n/\n")

    (out / "ww3_grid.nml").write_text(f"""! ww3-lab benchmark case -- generated, do not hand-edit
&SPECTRUM_NML
  SPECTRUM%XFR   = 1.1
  SPECTRUM%FREQ1 = {FREQ1}
  SPECTRUM%NK    = {nk}
  SPECTRUM%NTH   = {nth}
/
&RUN_NML
  RUN%FLCX  = T
  RUN%FLCY  = T
  RUN%FLCTH = T
  RUN%FLCK  = F
  RUN%FLSOU = T
/
&TIMESTEPS_NML
  TIMESTEPS%DTMAX = {ts['dtmax']}
  TIMESTEPS%DTXY  = {ts['dtxy']}
  TIMESTEPS%DTKTH = {ts['dtkth']}
  TIMESTEPS%DTMIN = {ts['dtmin']}
/
&GRID_NML
  GRID%NAME  = 'WW3LAB BENCH {nx}x{ny}'
  GRID%NML   = 'namelists.nml'
  GRID%TYPE  = 'RECT'
  GRID%COORD = 'CART'
  GRID%CLOS  = 'NONE'
  GRID%ZLIM  = -0.10
  GRID%DMIN  = 2.50
/
&RECT_NML
  RECT%NX  = {nx}
  RECT%NY  = {ny}
  RECT%SX  = {dx_m}
  RECT%SY  = {dx_m}
  RECT%SF  = 1.
  RECT%X0  = 0.
  RECT%Y0  = 0.
  RECT%SF0 = 1.
/
&DEPTH_NML
  DEPTH%SF       = -1.
  DEPTH%FILENAME = 'depth.inp'
  DEPTH%IDLA     = 1
/
&MASK_NML
  MASK%FILENAME = 'mask.inp'
  MASK%IDLA     = 1
/
""")

    start = datetime.datetime(2020, 1, 1)
    stop = start + datetime.timedelta(hours=hours)
    fmt = "%Y%m%d %H%M%S"
    (out / "ww3_shel.nml").write_text(f"""&DOMAIN_NML
  DOMAIN%START = '{start.strftime(fmt)}'
  DOMAIN%STOP  = '{stop.strftime(fmt)}'
/
&INPUT_NML
  INPUT%FORCING%WINDS = 'H'
/
&OUTPUT_TYPE_NML
  TYPE%FIELD%LIST = 'HS'
/
&OUTPUT_DATE_NML
  DATE%FIELD = '20200101 000000' '0' '20200101 000000'
/
&HOMOG_COUNT_NML
  HOMOG_COUNT%N_WND = 1
/
&HOMOG_INPUT_NML
  HOMOG_INPUT(1)%NAME   = 'WND'
  HOMOG_INPUT(1)%DATE   = '20200101 000000'
  HOMOG_INPUT(1)%VALUE1 = 12.
  HOMOG_INPUT(1)%VALUE2 = 270.
  HOMOG_INPUT(1)%VALUE3 = 0.
/
""")
    # Field output stride is '0' on purpose: we are timing COMPUTE, not I/O.
    # Writing hourly fields on a large grid can dominate the measurement and
    # turn a compute benchmark into a disk benchmark.

    meta = dict(nx=nx, ny=ny, nk=nk, nth=nth, hours=hours, dx_m=dx_m,
                timesteps=ts,
                sea_points=(nx - 1) * ny,
                spectral_bins=nk * nth,
                state_values=(nx - 1) * ny * nk * nth,
                state_mb=(nx - 1) * ny * nk * nth * 4 / 1e6)
    (out / "case.json").write_text(json.dumps(meta, indent=2))

    print(f"wrote {out}")
    print(f"  grid          : {nx} x {ny} at {dx_m/1000:.0f} km")
    print(f"  spectrum      : {nk} freq x {nth} dir = {nk*nth} bins")
    print(f"  sea points    : {meta['sea_points']:,}")
    print(f"  state array   : {meta['state_mb']:.0f} MB (single precision)")
    print(f"  timesteps     : DTMAX={ts['dtmax']:.0f} DTXY={ts['dtxy']:.0f} "
          f"DTKTH={ts['dtkth']:.0f} DTMIN={ts['dtmin']:.0f}")
    print(f"  global steps  : {int(hours * 3600 / ts['dtmax'])}")
    print("  field output  : disabled (timing compute, not disk)")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--size", choices=list(SIZES), default="medium")
    ap.add_argument("--nx", type=int)
    ap.add_argument("--ny", type=int)
    ap.add_argument("--nk", type=int)
    ap.add_argument("--nth", type=int)
    ap.add_argument("--hours", type=int)
    ap.add_argument("--dx-km", type=float, default=20.0)
    ap.add_argument("-o", "--out", default=None)
    a = ap.parse_args()

    cfg = dict(SIZES[a.size])
    for k in ("nx", "ny", "nk", "nth", "hours"):
        if getattr(a, k) is not None:
            cfg[k] = getattr(a, k)

    out = pathlib.Path(a.out or f"case_{a.size}")
    write_case(out, dx_m=a.dx_km * 1000.0, **cfg)


if __name__ == "__main__":
    main()
