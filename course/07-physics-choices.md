# 07 — Physics choices: which source terms, and why it matters

Everything here is a **compile-time** choice in the switch file. Changing it means a full
rebuild. See [`../switches/README.md`](../switches/README.md).

## The source-term packages

| Package | Origin | Character |
|---|---|---|
| `ST0` | none | Wind input and dissipation off entirely. For pure propagation tests. |
| `ST1` | WAM Cycle 3 | Historical. Don't. |
| `ST2` | Tolman & Chalikov (1996) | The old WW3 default. Still in use operationally at some centres. |
| `ST3` | WAM Cycle 4 / Bidlot | ECMWF lineage. |
| **`ST4`** | **Ardhuin et al. (2010)** | Saturation-based dissipation plus an explicit swell-dissipation term. The most widely used choice for regional and global work today. Has a large, well-explored tuning parameter space. |
| **`ST6`** | **Rogers, Babanin, Zieger** | Built from direct field observations of wind input and whitecapping rather than from closure arguments. Pairs with `FLX4`. Increasingly popular, particularly for extreme conditions. |

Pick one. They are **matched sets** — the input and dissipation terms in a package are
tuned against each other, and mixing them produces nonsense.

## Why this matters more than you'd like

$S_{in}$ and $S_{ds}$ are each large, each uncertain at the tens-of-percent level, and they
nearly cancel. The evolution of the spectrum is the small residual. Two defensible modern
packages, run on the same grid with the same winds, can differ by 10–20% in `Hs` and more
in period.

This is not a failure of WW3. It is the honest current state of wind-wave physics. The
practical implication: **your model has a tuning, and you should know what it is.** Running
`ST4` and `ST6` on the same case and comparing is one of the most educational things you
can do, and `examples/01` is set up for exactly that.

## The nonlinear term

`NL1` — the Discrete Interaction Approximation (Hasselmann et al. 1985) — is what almost
everyone runs. It approximates the four-wave resonant interaction integral with a single
representative quadruplet configuration.

- `NL2` computes it (nearly) exactly, at roughly 1000× the cost. Research only.
- `NL3` is the Generalized Multiple DIA: several quadruplets with optimised coefficients.
  Better, more expensive, and the coefficients need fitting —
  [`genes_gmd`](https://github.com/NOAA-EMC/genes_gmd) exists for that.

`NL1` is simultaneously the most important and the most approximate term in the model. Some
of what `ST4`/`ST6` tuning is compensating for is DIA error, not real physics. Worth
knowing when you're tempted to interpret a tuning constant physically.

## Propagation

`PR3 UQ` — third-order ULTIMATE QUICKEST with the Garden Sprinkler Effect correction — is
the default and the right answer for almost everything. Alternatives: `PR1` first-order
upwind (very diffusive, but rock stable), `PR2` second-order, `PR0` no propagation.

The **Garden Sprinkler Effect** is worth understanding: with a discrete direction grid,
each bin propagates as an independent ray, so a swell field far from its source
disintegrates into separate beams. It is a pure discretisation artefact. `PR3`'s correction
diffuses across directions to suppress it. More direction bins also helps. If you see
striping in a swell field far from the storm, this is why.

## Shallow water

| Switch | Physics |
|---|---|
| `BT1` | JONSWAP empirical bottom friction. Fine by default. |
| `BT4` | SHOWEX movable-bed friction. Needs a `D50` sediment map (`&SED_NML`, `&SBT4 SEDMAPD50 = T`). |
| `DB1` | Battjes-Janssen depth-induced breaking. |
| `MLIM` | Miche-style limiter on `Hs` in shallow water. |
| `TR0`/`TR1` | Triad (three-wave) interactions — surf-zone energy transfer to harmonics. |
| `REF1` | Shoreline reflection. Needs a slope map (`&SLOPE_NML`, `&REF1 REFMAP = 2`). |

If your domain is entirely in deep water, none of this fires and you can leave the defaults.

## Sea ice

`IC0` (off) through `IC5`, plus `IS1`/`IS2` for scattering. `IC5` (the extended
Fox-Squire model) arrived in v6.06. The ice forcing fields come in through
`INPUT%FORCING%ICE_CONC` and `ICE_PARAM1`…`5` (thickness, floe size, viscosity …).

Marginal-ice-zone wave physics is an active research area and the parameterisations
disagree with each other substantially more than the open-water ones do.

## Tuning namelists

Physics constants live in the file pointed at by `GRID%NML` (conventionally
`namelists.nml`), read by `ww3_grid`:

```
&SIN4
  BETAMAX = 1.52     ! the master gain on wind input. Bump this, everything gets bigger.
/
&SDS4
  SDSBCHOICE = 2
/
&MISC
  FLAGTR = 0
/
```

`ww3_grid` writes the namelists it actually used into `param.scratch` and echoes them to
stdout. Check that file — it tells you what the model is really running, as opposed to what
you thought you configured. Blocks irrelevant to your switch settings are silently skipped,
which means a typo'd namelist name fails quietly.

## A note on tuning

The temptation, once you've validated against a buoy and found a bias, is to reach for
`BETAMAX`. Resist it until you've checked, in this order:

1. Your winds (the dominant error source, usually by a wide margin)
2. Your bathymetry and obstruction grids
3. Your boundary conditions / missing swell
4. Your spectral range — is `FREQ1` low enough for the swell that's actually there?
5. Your resolution
6. *Then* the physics constants

Tuning a source term to compensate for a bad wind field produces a model that's right for
the wrong reason and will fail on the next storm.

→ [`08-python.md`](08-python.md)
