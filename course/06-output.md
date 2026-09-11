# 06 — Output and post-processing

## The seven output types

Configured in `&OUTPUT_TYPE_NML` (what) and `&OUTPUT_DATE_NML` (when) in `ww3_shel.nml`.
A stride of `'0'` disables a type.

1. **Gridded fields** — `Hs`, periods, direction, etc. on the model grid. → `out_grd.ww3`
   → `ww3_ounf` → netCDF. The one you'll use 90% of the time.
2. **Point spectra** — full 2D frequency-direction spectra at named locations.
   → `out_pnt.ww3` → `ww3_ounp` → netCDF. This is the model's actual state, not a summary.
3. **Track output** — fields along a moving track. For satellite collocation.
   → `ww3_trnc`.
4. **Restart files** — the complete model state, for continuing a run.
5. **Boundary data** — spectra along declared output boundaries, for feeding a child grid.
   Mostly superseded by using point output + `ww3_bounc` instead.
6. **Separated wave fields** — spatially and temporally coherent wave *systems* tracked
   across the domain. See the `ww3_systrk` program and IFREMER's `TUTORIAL_WAVETRACK`.
7. **Coupling fields** — for NUOPC/ESMF/OASIS coupled runs.

## Fields worth knowing

```
DPT CUR WND AST WLV ICE IBG D50 IC1 IC5
HS LM T02 T0M1 T01 FP DIR SPR DP HIG
EF TH1M STH1M TH2M STH2M WN
PHS PTP PLP PDIR PSPR PWS PDP PQP PPE PGW PSW PTM10 PT01 PT02 PEP TWS PNR
UST CHA CGE FAW TAW TWA WCC WCF WCH WCM FWS
SXY TWO BHD FOC TUS USS P2S USF P2L TWI FIC
ABR UBR BED FBB TBB
MSS MSC WL02 AXT AYT AXY
```
(the authoritative list with descriptions is at the top of `$WW3/model/nml/ww3_ounf.nml`)

Ones you'll actually reach for:

| Field | What |
|---|---|
| `HS` | significant wave height — 4√(total energy) |
| `T01`, `T02`, `T0M1` | mean periods from different spectral moments. **They are not interchangeable**; buoy products and models frequently compare the wrong pair. `T0M1` (energy period) is what most engineering work wants. |
| `FP`, `DP` | peak frequency and peak direction |
| `DIR`, `SPR` | mean direction and directional spread |
| `EF` | the 1D frequency spectrum on the model grid |
| `PHS PTP PDIR PSPR PWS` | **partitioned**: wind sea + N swell systems, separately |
| `USS`, `TUS` | Stokes drift — what you hand to an ocean model |
| `SXY` | radiation stresses — what drives nearshore circulation |
| `UST`, `CHA` | friction velocity, Charnock — what you hand back to an atmosphere model |
| `WND`, `DPT` | echo the inputs back. Free, and catches errors instantly. |

## Partitioning: the thing to actually understand

A total `Hs` of 2 m can be a 2 m wind sea, or a 2 m swell, or a 1.4 m sea plus 1.4 m of
swell from a completely different direction. These are different oceans and different
engineering problems, and a single number cannot distinguish them.

WW3 partitions the 2D spectrum into a wind sea and up to `NOSWLL` swell systems using a
watershed algorithm on the spectral surface, and reports `PHS(n)`, `PTP(n)`, `PDIR(n)` for
each. `FIELD%PARTITION = '0 1 2 3'` in `ww3_ounf.nml` selects which to write (0 = wind sea).

`wavespectra` implements the same family of algorithms (`ptm1` … `ptm5`, plus watershed and
wave-age variants) so you can re-partition offline with different parameters without
rerunning the model.

## Reading the output

```python
import xarray as xr
ds = xr.open_dataset("ww3.nc")
ds.hs.isel(time=-1).plot()
```

For spectra, use [`wavespectra`](https://github.com/wavespectra/wavespectra) — it has a
native WW3 reader and an xarray `.spec` accessor:

```python
from wavespectra import read_ww3

dset = read_ww3("ww3.20240701_spec.nc")

dset.spec.hs()        # significant wave height from the spectrum
dset.spec.tp()        # peak period
dset.spec.dpm()       # peak direction
dset.spec.dspr()      # directional spread
dset.spec.stats(["hs", "tp", "dpm", "dspr"])

dset.spec.oned()                        # collapse to 1D frequency spectrum
dset.spec.split(fmin=0.04, fmax=0.10)   # just the swell band
dset.spec.partition.ptm1()              # re-partition offline

dset.isel(time=0, site=0).spec.plot(kind="contourf")   # polar plot
```

A useful consistency check: `dset.spec.hs()` computed from the spectrum should match the
`HS` field `ww3_ounf` wrote. If they disagree, one of them is being computed over a
different frequency range than you think.

## Validation

[`NOAA-EMC/WW3-tools`](https://github.com/NOAA-EMC/WW3-tools) is the official toolkit:
altimeter collocation, NDBC buoy matching, scatter plots, QQ plots, Taylor diagrams, and
the standard metric set.

Rough expectations for a regional run with default tuning and decent winds: `Hs` bias
within ±10%, scatter index 15–25%. Periods are worse — `Tp` in particular is a noisy
statistic and comparing it point-to-point against a buoy is a good way to feel bad about
yourself. Compare `T0M1` instead, and compare *distributions* as well as time series.

If your first attempt looks dramatically better than that, check that you aren't
accidentally comparing the model against itself.

→ [`07-physics-choices.md`](07-physics-choices.md)
