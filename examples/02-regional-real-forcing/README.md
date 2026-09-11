# Example 02 — regional run, real bathymetry, real winds

Southern Brazil shelf: 52°W–44°W, 32°S–24°S at 0.1°. Florianópolis sits in the middle of it.

This is where WW3 stops being a toy. Example 01 had no geography, no data files, and no way
to be wrong about coordinate conventions. This one has all three.

## What you have to supply

| File | Where from |
|---|---|
| `gebco.nc` | [GEBCO 2024 subsetted download](https://download.gebco.net/) for the box above |
| `era5_winds.nc` | `python3 get_era5.py` (needs a free Copernicus CDS account + `~/.cdsapirc`) |

## Run

```bash
export WW3=$HOME/src/WW3
./run.sh
```

## New concepts, in the order you hit them

**Spherical coordinates.** `GRID%COORD = 'SPHE'` and `RECT%SX/SY` are now degrees, not
metres. The CFL calculation has to use the *smallest* physical cell size, which at 30°S is
the zonal one: `0.1° × 111320 × cos(30°) ≈ 9.6 km`. Get this wrong and the model is either
unstable or needlessly slow.

**Lower `FREQ1`.** The default 0.04118 Hz corresponds to a 24 s period. South Atlantic
swell from the Southern Ocean is routinely longer than that. Energy below your lowest bin
doesn't get truncated with a warning — it just never exists. Choosing `FREQ1` is a physical
decision about what you're modelling.

**Open boundaries.** Swell generated thousands of kilometres away has to enter the domain
somehow. `INBND_POINT` in `ww3_grid.nml` marks where, and `ww3_bounc` fills them with
spectra from a coarser parent run. Two rules that bite everyone:
- Boundary points must be *inside* the grid, never on the first or last row/column.
- A `CONNECT = T` flag fills in every point on the straight line from the previous point,
  which is how you specify an edge with two entries instead of eighty.

For a first run you can skip boundaries entirely (delete the `INBND_*` blocks). You'll get
locally generated wind sea only — which is actually a useful comparison, because the
difference between that and the boundary-fed run *is* the remote swell contribution.

**`ww3_prnc`.** Converts netCDF forcing onto the model grid and into WW3's binary format.
One run per forcing type; you swap the namelist between invocations. The failure mode to
watch for is longitude convention: if ERA5 comes on 0–360 and your grid is on −180–180,
you may get a silent field of zeros rather than an error.

**Partitioned output.** `PHS`, `PTP`, `PDIR` split the spectrum into wind sea plus swell
systems. On this coast you'll typically see a local sea plus one or two distinct Southern
Ocean swell trains. Total `Hs` blends them into one number that describes neither.

**Point/spectral output.** `points.list` names five sites; `ww3_ounp` writes their full
2D spectra to netCDF, which [`wavespectra`](https://github.com/wavespectra/wavespectra)
reads natively with `read_ww3()`.

## Exercises

1. **Where does the swell come from?** Take the deep offshore point's 2D spectrum at a time
   when a swell train is present. Read off peak period and mean direction, compute the
   deep-water group velocity `cg = g/(4πf)`, and back out how far away and how long ago it
   was generated. Then check a surface-pressure chart for that date. This is the single most
   satisfying thing you can do with a wave model.

2. **Resolution matters where?** Rerun at 0.05°. Where does the answer change — offshore or
   over the shelf? What does that tell you about where the resolution budget should go?

3. **Boundaries on vs off.** Run with and without `nest.ww3`. Map the difference in `Hs`.
   How far into the domain does the boundary influence reach, and how fast?

4. **Validate.** Pull the nearest available buoy or altimeter track for the period and use
   [`WW3-tools`](https://github.com/NOAA-EMC/WW3-tools) to compute bias, RMSE, scatter index.
   A regional run with default tuning typically lands within 10–20% on `Hs` and does worse
   on period. Anything dramatically better on a first attempt is suspicious.

5. **Obstruction grids.** The small islands off Florianópolis are unresolved at 0.1°.
   Generate an obstruction grid with `gridgen`, set `FLAGTR = 1`, and see what changes in
   the lee.

## ⚠ Caveats

Written from documentation, not executed. The `ww3_prnc` and `ww3_ounp` namelists in
particular have more optional blocks than shown here — check them against
`$WW3/model/nml/ww3_prnc.nml` and `$WW3/model/nml/ww3_ounp.nml` in your clone, which are
the authoritative annotated templates.
