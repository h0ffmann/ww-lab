#!/usr/bin/env python3
"""Compare WW3's fetch-limited growth against the classic empirical laws.

This is the payoff of example 01. WW3 integrates a five-dimensional PDE with
a fully parameterised source-term balance; the empirical growth laws are
curve fits to field campaigns from the 1970s-80s. They should agree to within
tens of percent over the fetch range where the wind sea is still growing.
Where they disagree tells you something -- usually about full development,
or about the tuning of whichever ST package you compiled.

Usage:
    python analyse.py [ww3.nc]
"""

from __future__ import annotations

import sys

import numpy as np
import xarray as xr

G = 9.806


def kahma_calkoen(x_hat: np.ndarray) -> np.ndarray:
    """Dimensionless energy vs dimensionless fetch (Kahma & Calkoen 1992,
    composite/stable-corrected coefficients). Returns e_hat = g^2 E / U10^4."""
    return 5.2e-7 * x_hat**0.9


def hs_from_ehat(e_hat: np.ndarray, u10: float) -> np.ndarray:
    """Hs = 4 sqrt(E), with E recovered from the dimensionless energy."""
    energy = e_hat * u10**4 / G**2
    return 4.0 * np.sqrt(energy)


def pierson_moskowitz_hs(u10: float) -> float:
    """Fully developed limit. Nothing should exceed this at steady state."""
    return 0.0246 * u10**2


def main() -> int:
    path = sys.argv[1] if len(sys.argv) > 1 else "ww3.nc"
    try:
        ds = xr.open_dataset(path)
    except (FileNotFoundError, OSError):
        print(f"could not open {path!r} -- run ./run.sh first", file=sys.stderr)
        return 1

    print(ds)
    print()

    # ww3_ounf names the horizontal coords 'x'/'y' for Cartesian grids and
    # 'longitude'/'latitude' for spherical ones. Handle both.
    xname = "x" if "x" in ds.dims else ("longitude" if "longitude" in ds.dims else None)
    yname = "y" if "y" in ds.dims else ("latitude" if "latitude" in ds.dims else None)
    if xname is None:
        print(f"unexpected dims {tuple(ds.dims)} -- inspect the file by hand", file=sys.stderr)
        return 1

    hs = ds["hs"].isel(time=-1)          # final time = steady state
    hs = hs.isel({yname: hs.sizes[yname] // 2})  # centre row, away from edges

    x = ds[xname].values.astype(float)
    if x.max() < 1e4:  # some builds report km or degrees; assume metres otherwise
        print("note: x looks small -- check units before trusting the fetch axis")

    fetch = x - x.min()          # metres from the coastline at i=1
    hs_model = hs.values

    u10 = 10.0                   # must match HOMOG_INPUT(1)%VALUE1
    with np.errstate(divide="ignore", invalid="ignore"):
        x_hat = G * fetch / u10**2
        hs_emp = hs_from_ehat(kahma_calkoen(x_hat), u10)
    hs_pm = pierson_moskowitz_hs(u10)

    print(f"U10 = {u10:.1f} m/s      Pierson-Moskowitz fully-developed Hs = {hs_pm:.2f} m")
    print()
    print(f"{'fetch [km]':>11} {'WW3 Hs [m]':>11} {'K&C92 Hs [m]':>13} {'ratio':>7}")
    for i in range(1, len(fetch), max(1, len(fetch) // 12)):
        ratio = hs_model[i] / hs_emp[i] if hs_emp[i] > 0 else float("nan")
        print(f"{fetch[i]/1000:11.0f} {hs_model[i]:11.3f} {hs_emp[i]:13.3f} {ratio:7.2f}")

    print()
    print("What to look for:")
    print("  * Hs should increase monotonically with fetch. If it decreases, your")
    print("    wind direction convention is flipped -- see the note in ww3_shel.nml.")
    print("  * Ratio should sit near 1 over most of the fetch, drifting as the sea")
    print("    approaches full development.")
    print(f"  * Nothing should meaningfully exceed {hs_pm:.2f} m at steady state.")

    try:
        import matplotlib.pyplot as plt
    except ImportError:
        print("\n(install matplotlib for the plot)")
        return 0

    fig, ax = plt.subplots(figsize=(7, 4.5))
    ax.plot(fetch / 1000, hs_model, lw=2, label="WW3")
    ax.plot(fetch / 1000, hs_emp, "--", lw=1.5, label="Kahma & Calkoen 1992")
    ax.axhline(hs_pm, color="grey", ls=":", label="Pierson-Moskowitz limit")
    ax.set_xlabel("fetch [km]")
    ax.set_ylabel("$H_s$ [m]")
    ax.set_title(f"Fetch-limited growth, $U_{{10}}$ = {u10:.0f} m/s")
    ax.legend()
    ax.grid(alpha=0.3)
    fig.tight_layout()
    fig.savefig("fetch_growth.png", dpi=130)
    print("\nwrote fetch_growth.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
