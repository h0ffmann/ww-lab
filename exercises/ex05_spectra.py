#!/usr/bin/env python3
"""Exercise 5 — spectra: ww3_ounp + wavespectra.

Gridded Hs is a summary. The spectrum is the model's actual state. This
exercise gets at it.

Goal: write point spectra with ww3_ounp, read them with wavespectra, and
verify that Hs recovered from the spectrum matches the HS field WW3 wrote.
If those two disagree you have learned something important about frequency
ranges.

    pip install wavespectra
"""

from __future__ import annotations

import pathlib

import numpy as np
import xarray as xr
from pyww3.ounp import WW3Ounp
from wavespectra import read_ww3

RUN = pathlib.Path("runs/ex02").absolute()


def main() -> None:
    # ------------------------------------------------------------------
    # TODO 1. You need point output, which means ex02 must have been run
    # with TYPE%POINT%FILE set. Create a points.list in runs/ex02:
    #
    #   0.0      40000.0  'COAST'
    #   400000.0 40000.0  'MID'
    #   1200000.0 40000.0 'FAR'
    #
    # (Cartesian grid, so these are metres. Column 3 is the point name,
    # in quotes, max 40 chars.)
    #
    # Then rerun ex02 with:
    #   type_point_file="runs/ex02/points.list"
    #   date_point_stride=3600
    # ------------------------------------------------------------------

    # ------------------------------------------------------------------
    # TODO 2. Run ww3_ounp with SPECTRA%OUTPUT = 3 (full 2D spectrum).
    #
    #   W = WW3Ounp(runpath=str(RUN), mod_def=str(RUN / "mod_def.ww3"), ...)
    #
    # Other SPECTRA%OUTPUT values: 1 = 1D frequency spectrum,
    # 2 = mean parameters, 4 = source terms. Option 4 is worth a look
    # later -- it writes Sin, Snl, Sds separately, which is the only way
    # to actually see the source-term balance.
    # ------------------------------------------------------------------

    # ------------------------------------------------------------------
    # TODO 3. Read with wavespectra and compute statistics.
    #
    #   spec = sorted(RUN.glob("ww3*spec*.nc"))[0]
    #   dset = read_ww3(str(spec))
    #   print(dset)
    #   print(dset.spec.stats(["hs", "tp", "dpm", "dspr"]))
    # ------------------------------------------------------------------

    # ------------------------------------------------------------------
    # TODO 4. THE CHECK. Compare dset.spec.hs() at the FAR point against
    # the HS value ww3_ounf wrote at the same grid cell and time.
    #
    # They should agree closely. If they don't, the likely cause is the
    # high-frequency tail: WW3 adds an analytical f^-5 tail beyond its
    # highest resolved frequency when computing HS, and whether that
    # contribution is present depends on what you're integrating. This is
    # a genuine subtlety, not a bug, and knowing about it will save you
    # an afternoon at some point.
    # ------------------------------------------------------------------

    # ------------------------------------------------------------------
    # TODO 5. Plot the 2D spectrum at the FAR point, at the final time:
    #
    #   dset.isel(time=-1, site=-1).spec.plot(kind="contourf")
    #
    # Then plot the COAST point on the same colour scale. You are looking
    # at the same wind field producing two completely different spectra:
    # near the coast a narrow, high-frequency, young sea; far downwind a
    # broader, lower-frequency, more developed one. The migration of the
    # peak towards lower frequency with fetch IS the nonlinear transfer
    # term (NL1) doing its job. You can see the DIA working.
    # ------------------------------------------------------------------

    # ------------------------------------------------------------------
    # TODO 6 (stretch). Fit a JONSWAP spectrum to the FAR point's 1D
    # spectrum (dset.spec.oned()) and recover the peak enhancement factor
    # gamma. Compare against the canonical 3.3. Then do it at COAST.
    # Young seas are more peaked. wavespectra can construct JONSWAP
    # spectra for you to fit against.
    # ------------------------------------------------------------------

    raise SystemExit("Work through the TODOs above, then remove this line.")


if __name__ == "__main__":
    main()
