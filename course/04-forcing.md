# 04 — Forcing: winds, currents, ice, water levels

## What WW3 will accept

| Forcing | Why it matters | `INPUT%FORCING%…` |
|---|---|---|
| **10 m winds** | The engine. Everything else is a correction. | `WINDS` |
| Currents | Refraction, frequency shift, and the Agulhas/Gulf Stream giant-wave problem. | `CURRENTS` |
| Water levels | Tides. Matters in shallow water, irrelevant offshore. | `WATER_LEVELS` |
| Ice concentration | Attenuates and scatters. | `ICE_CONC` |
| Ice thickness/floe size | Needed by the more sophisticated ice physics (`IC2`–`IC5`). | `ICE_PARAM1`…`5` |
| Mud | Dissipation over muddy bottoms. Niche. | `MUD_DENSITY`, … |
| Air density, momentum | Mostly for coupled configurations. | — |

Each takes `'T'` (from a file), `'H'` (homogeneous constant, given in
`&HOMOG_INPUT_NML`), or `'C'` (from a coupler).

## Winds are everything

Wave model error is dominated by wind error, not by wave physics. A 10% wind speed error
becomes roughly a 20% error in `Hs` in a growing sea (energy goes roughly as `U²` in the
fetch-limited laws, and worse than that in the growth phase). Before you spend a week
tuning `BETAMAX`, check your winds against scatterometer data.

Practical consequences:

- **Resolution.** ERA5 at 0.25° cannot represent a squall line or a tight tropical cyclone
  core. For storm cases you want a higher-resolution atmospheric model, not a finer wave
  grid.
- **Temporal frequency.** Hourly is the minimum for anything with a front in it. 6-hourly
  winds smear out exactly the events you care about.
- **Height.** WW3 wants 10 m winds. If your source gives a different level, convert with a
  log profile — or better, use `&SIN4 ZWND` / the equivalent for your source-term package
  to tell WW3 what height it's being given.
- **Stability.** `HOMOG_INPUT(i)%VALUE3` and the `STAB` switch handle air-sea temperature
  difference. A cold-air outbreak over warm water generates markedly more wave energy than
  the same wind speed in stable conditions.

## ww3_prnc

```bash
cp ww3_prnc_wind.nml ww3_prnc.nml
ww3_prnc | tee ww3_prnc_wind.out
```

It interpolates a netCDF field onto your model grid and writes WW3's binary format
(`wind.ww3`, `current.ww3`, `ice.ww3`, `level.ww3`). Key namelist fields:

```
&FORCING_NML
  FORCING%FIELD%WINDS = T
  FORCING%GRID%LATLON = T
  FORCING%TIMESTART   = 'YYYYMMDD HHMMSS'
  FORCING%TIMESTOP    = 'YYYYMMDD HHMMSS'
/
&FILE_NML
  FILE%FILENAME  = 'era5_winds.nc'
  FILE%LONGITUDE = 'longitude'
  FILE%LATITUDE  = 'latitude'
  FILE%VAR(1)    = 'u10'
  FILE%VAR(2)    = 'v10'
/
```

### The four things that go wrong

1. **Variable names.** `u10` vs `U10` vs `10u` vs `eastward_wind`. `ncdump -h` first.
2. **Coordinate names.** ERA5 has shipped both `time` and `valid_time` across CDS format
   revisions.
3. **Longitude convention.** 0–360 vs −180–180. If your grid is at −52° and your forcing is
   at 308°, you may get a silent field of zeros rather than an error. Fix in xarray:
   ```python
   ds = ds.assign_coords(longitude=(((ds.longitude + 180) % 360) - 180)).sortby("longitude")
   ```
4. **Coverage.** The forcing must cover the model domain *and* the model time window with a
   margin. WW3 will not extrapolate off the end of your winds; it will stop, or hold the
   last field, depending on version.

### Verify before you run the model

Always output `WND` as a model field and look at it. If `ww3_prnc` silently produced
nothing useful, a map of the wind WW3 *actually used* shows it in two seconds. This is the
cheapest debugging habit in wave modelling.

## Boundary spectra

Locally generated wind sea is only part of the picture. Swell arrives from thousands of
kilometres away, and on many coasts it dominates.

```
parent run  →  ww3_ounp (spectral netCDF at points along the child's boundary)
                  ↓
            ww3_bounc  →  nest.ww3  →  read automatically by ww3_shel
```

`ww3_bounc` reads a `spec.list` file naming the spectral netCDF files to use:

```bash
ls ../configs/GLOBAL_30MIN/SPEC/ww3.*spec.nc > spec.list
ww3_bounc
```

There is no flag in `ww3_shel.nml` to enable boundaries — if `nest.ww3` exists in the run
directory it is used. Check `log.ww3`: the input timeline shows boundary updates.

The alternative for global-scale sources: use NOAA's operational GFS-Wave output, or an
IFREMER hindcast, as your parent. You don't have to run the global grid yourself.

## Exercise

Take example 02, run it twice — once with boundary spectra, once without — and map the
difference in `Hs`. The result is a map of "how much of the wave climate here comes from
somewhere else". For the southern Brazil shelf in winter, it is most of it.

→ [`05-nesting.md`](05-nesting.md)
