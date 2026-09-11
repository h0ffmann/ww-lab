#!/usr/bin/env python3
"""Write the ASCII depth and mask files that ww3_grid reads for example 01.

WW3's grid preprocessor wants plain ASCII arrays for bathymetry and the
land/sea mask, one row per line, in a layout you declare via IDLA. We use
IDLA=1, which means "line by line, starting from the BOTTOM row (j=1)".

Nothing clever happens here. The point of generating it from Python rather
than committing a static file is that you can change NX/NY/depth and re-run,
which is exactly what the exercises ask you to do.
"""

NX = 61
NY = 5
DEPTH_M = 250.0  # positive metres; ww3_grid.nml has DEPTH%SF = -1. to flip it

# Mask legend (from model/nml/ww3_grid.nml):
#   -2 excluded boundary point (ice)   -1 excluded sea point (ice)
#    0 excluded land point              1 sea point
#    2 active boundary point            3 excluded grid point
#    7 ice point
LAND, SEA = 0, 1


def main() -> None:
    with open("depth.inp", "w") as fh:
        for _ in range(NY):
            fh.write(" ".join(f"{DEPTH_M:.1f}" for _ in range(NX)) + "\n")

    with open("mask.inp", "w") as fh:
        for _ in range(NY):
            row = [LAND] + [SEA] * (NX - 1)  # i=1 is the coastline
            fh.write(" ".join(str(v) for v in row) + "\n")

    fetch_km = (NX - 1) * 20.0
    print(f"wrote depth.inp and mask.inp  ({NX} x {NY}, {DEPTH_M:.0f} m flat)")
    print(f"maximum fetch from the coast: {fetch_km:.0f} km")


if __name__ == "__main__":
    main()
