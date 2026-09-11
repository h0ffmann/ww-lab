#!/usr/bin/env python3
"""Exercise 2 — run the model from Python.

Depends on: ex01 having produced runs/ex01/mod_def.ww3.

Goal: drive ww3_shel with homogeneous 10 m/s wind for 48 hours and get
out_grd.ww3 out of it.
"""

from __future__ import annotations

import datetime
import pathlib
import shutil

from pyww3.shel import WW3Shel

SRC = pathlib.Path("runs/ex01").absolute()
RUN = pathlib.Path("runs/ex02").absolute()


def main() -> None:
    RUN.mkdir(parents=True, exist_ok=True)
    shutil.copy(SRC / "mod_def.ww3", RUN / "mod_def.ww3")

    # ------------------------------------------------------------------
    # TODO 1. Construct WW3Shel.
    #
    #   nproc=1                        (serial build; use your core count for MPI)
    #   runpath=str(RUN)
    #   mod_def=str(RUN / "mod_def.ww3")
    #   domain_start=datetime.datetime(2020, 1, 1, 0)
    #   domain_stop =datetime.datetime(2020, 1, 3, 0)
    #   input_forcing_winds=True
    #   date_field_stride=3600
    #   type_field_list=["HS", "T01", "T0M1", "FP", "DIR", "SPR", "WND", "DPT"]
    #
    # Note that input_forcing_winds=True maps to INPUT%FORCING%WINDS.
    # ------------------------------------------------------------------
    W = WW3Shel(
        runpath=str(RUN),
        mod_def=str(RUN / "mod_def.ww3"),
        domain_start=datetime.datetime(2020, 1, 1, 0),
        domain_stop=datetime.datetime(2020, 1, 3, 0),
        input_forcing_winds=True,
        # ... TODO
    )

    # ------------------------------------------------------------------
    # TODO 2. Homogeneous wind.
    #
    # ⚠ pyww3's coverage of &HOMOG_COUNT_NML / &HOMOG_INPUT_NML is the
    # weakest part of the wrapper -- it may not expose them as keywords at
    # all. This is exactly what update_text() is for. Append the blocks by
    # hand:
    #
    #   W.text += '''
    #   &HOMOG_COUNT_NML
    #     HOMOG_COUNT%N_WND = 1
    #   /
    #   &HOMOG_INPUT_NML
    #     HOMOG_INPUT(1)%NAME   = 'WND'
    #     HOMOG_INPUT(1)%DATE   = '20200101 000000'
    #     HOMOG_INPUT(1)%VALUE1 = 10.
    #     HOMOG_INPUT(1)%VALUE2 = 270.
    #     HOMOG_INPUT(1)%VALUE3 = 0.
    #   /
    #   '''
    #
    # This is the honest reality of thin wrappers, and a useful lesson:
    # know what the tool generates so you can patch it when it falls short.
    # ------------------------------------------------------------------

    # ------------------------------------------------------------------
    # TODO 3. Write, inspect, run.
    #
    #   W.to_file()
    #   print((RUN / "ww3_shel.nml").read_text())
    #   W.run()
    #   print(W.stdout)
    #
    # Then open runs/ex02/log.ww3 and find the timestep table. There is a
    # column per input showing when each forcing updated. Confirm the wind
    # column is doing something. If it isn't, the model ran on a calm sea
    # and your Hs will be zero everywhere.
    # ------------------------------------------------------------------

    # ------------------------------------------------------------------
    # TODO 4. Check out_grd.ww3 exists and is non-trivial in size.
    # ------------------------------------------------------------------


if __name__ == "__main__":
    main()
