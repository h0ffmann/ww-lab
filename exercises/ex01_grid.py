#!/usr/bin/env python3
"""Exercise 1 — build mod_def.ww3 from Python.

Goal: reproduce examples/01-fetch-limited-growth/ww3_grid.nml using pyww3,
run ww3_grid, and confirm you get an identical mod_def.ww3.

Why bother, when the .nml file already exists? Because being forced to name
every parameter in Python is the fastest way to learn the namelist, and
because everything after exercise 3 depends on generating configurations
programmatically rather than editing files by hand.

Run:  python ex01_grid.py
"""

from __future__ import annotations

import os
import pathlib

from pyww3.grid import WW3Grid  # note: the class is spelled WW3GRid in some
                                # versions of pyww3. If the import fails, try:
                                #   from pyww3.grid import WW3GRid as WW3Grid

RUN = pathlib.Path("runs/ex01").absolute()

# Must match examples/01-fetch-limited-growth/ww3_grid.nml
NX, NY = 61, 5
DX = 20000.0      # metres
DEPTH_M = 250.0


def write_grid_files(run: pathlib.Path) -> None:
    """ASCII bathymetry and mask, same as examples/01/make_inputs.py."""
    with open(run / "depth.inp", "w") as fh:
        for _ in range(NY):
            fh.write(" ".join(f"{DEPTH_M:.1f}" for _ in range(NX)) + "\n")
    with open(run / "mask.inp", "w") as fh:
        for _ in range(NY):
            fh.write(" ".join(["0"] + ["1"] * (NX - 1)) + "\n")
    # ww3_grid needs the physics-namelist file even if it is nearly empty.
    (run / "namelists.nml").write_text("&MISC\n  FLAGTR = 0\n/\n")


def main() -> None:
    RUN.mkdir(parents=True, exist_ok=True)
    write_grid_files(RUN)

    # ------------------------------------------------------------------
    # TODO 1. Fill in the constructor.
    #
    # Mapping reminder:  SECTION%FIELD  ->  section_field
    #
    #   SPECTRUM%XFR = 1.1      -> spectrum_xfr=1.1
    #   SPECTRUM%FREQ1 = 0.04118
    #   SPECTRUM%NK = 32
    #   SPECTRUM%NTH = 24
    #   GRID%TYPE = 'RECT'  COORD = 'CART'  CLOS = 'NONE'
    #   GRID%ZLIM = -0.10   GRID%DMIN = 2.50
    #   RECT%NX/NY/SX/SY/SF/X0/Y0/SF0
    #   DEPTH%SF = -1.   DEPTH%FILENAME = 'depth.inp'
    #   MASK%FILENAME = 'mask.inp'
    #   TIMESTEPS%DTMAX/DTXY/DTKTH/DTMIN = 2700/900/1350/10
    #
    # Note DEPTH%SF = -1. -- our file has POSITIVE depths and WW3 wants
    # negative below mean sea level.
    # ------------------------------------------------------------------
    W = WW3Grid(
        runpath=str(RUN),
        grid_name="FETCH CHANNEL 20KM",
        grid_nml="namelists.nml",
        grid_type="RECT",
        grid_coord="CART",
        grid_clos="NONE",
        # ... TODO: the rest
    )

    # ------------------------------------------------------------------
    # TODO 2. Remove the namelist blocks that don't apply to a RECT/CART
    # grid. pyww3 emits every block; ww3_grid objects to the irrelevant
    # ones. Remove at least: &CURV_NML, &UNST_NML, &SMC_NML, &SED_NML,
    # &SLOPE_NML, &OBST_NML
    #
    #   W.update_text("&CURV_NML", action="remove")
    # ------------------------------------------------------------------

    # ------------------------------------------------------------------
    # TODO 3. Write it out, print it, and READ IT. Compare line by line
    # against examples/01-fetch-limited-growth/ww3_grid.nml. Every
    # difference is either a pyww3 default you didn't override or a
    # mistake -- work out which.
    # ------------------------------------------------------------------
    W.to_file()
    print((RUN / "ww3_grid.nml").read_text())

    # ------------------------------------------------------------------
    # TODO 4. Run it, and read the output. ww3_grid prints a full grid
    # summary. Find the sea/land/boundary point counts and check them
    # against what you expect: 61*5 = 305 total, 5 land (column i=1),
    # 300 sea.
    # ------------------------------------------------------------------
    W.run()
    print(W.stdout)

    assert (RUN / "mod_def.ww3").exists(), "ww3_grid did not produce mod_def.ww3"
    print(f"\nOK -- mod_def.ww3 written to {RUN}")

    # ------------------------------------------------------------------
    # TODO 5 (the important one). Change a timestep AFTER construction and
    # watch what happens if you forget to regenerate the text:
    #
    #     W.timesteps_dtmax = 1440.
    #     W.to_file()
    #     print((RUN / "ww3_grid.nml").read_text())   # still says 2700!
    #
    #     W.text = W.populate_namelist()              # the fix
    #     W.to_file()
    #     print((RUN / "ww3_grid.nml").read_text())   # now 1440
    #
    # Do this once, deliberately, so you never do it accidentally.
    # ------------------------------------------------------------------


if __name__ == "__main__":
    if not os.environ.get("WW3"):
        print("warning: $WW3 not set; make sure ww3_grid is on PATH")
    main()
