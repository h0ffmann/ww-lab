# pyww3 exercises

Six exercises, roughly 20–60 minutes each. Each `exNN_*.py` has the scaffolding, the
docstring explaining what you're doing and why, and `TODO` markers. Working versions are in
`solutions/`.

## Setup

```bash
pip install pyww3 xarray netcdf4 matplotlib numpy
export WW3=$HOME/src/WW3          # your built clone
export PATH="$WW3/build/bin:$PATH"
```

`pyww3` shells out to the WW3 executables, so they must be on `PATH` and the model must be
compiled with `NC4`.

## The exercises

| | File | What you learn |
|---|---|---|
| 1 | `ex01_grid.py` | Build `mod_def.ww3` from Python. Namelist ↔ keyword mapping, `update_text`, the regenerate-the-text gotcha. |
| 2 | `ex02_shel.py` | Run the model. Homogeneous forcing, output types, reading `stdout` back. |
| 3 | `ex03_output.py` | `ww3_ounf` → netCDF → xarray. Verify against the fetch-growth laws. |
| 4 | `ex04_sweep.py` | Parameter sweep: one run per wind speed, all orchestrated in Python. This is the actual reason to script a model. |
| 5 | `ex05_spectra.py` | `ww3_ounp` + `wavespectra`. Recover `Hs` from the 2D spectrum and check it against the model's own `HS` field. |
| 6 | `ex06_pipeline.py` | Wrap the lot in a reusable `WW3Case` class with caching. Build the tool you'd actually use. |

Do them in order. Each builds on the previous one's output.

## The two things that will trip you up

**1. Parameter naming.** Namelist `SECTION%FIELD` becomes `section_field`, lowercased,
`%` → `_`:

```
SPECTRUM%FREQ1    ->  spectrum_freq1
TIMESTEPS%DTMAX   ->  timesteps_dtmax
GRID%ZLIM         ->  grid_zlim
RECT%NX           ->  rect_nx
DEPTH%FILENAME    ->  depth_filename
INPUT%FORCING%WINDS -> input_forcing_winds
```

**2. Mutating an attribute doesn't update the text.** The namelist string is built once, in
`__post_init__`. If you change a field afterwards you must rebuild it:

```python
W.timesteps_dtmax = 1440.
W.text = W.populate_namelist()   # <-- REQUIRED
W.to_file()
```

Forgetting this writes the old value and produces a run that silently ignores your change.
It's the single most common `pyww3` mistake and it's in the official docs for a reason.

## Debugging

`pyww3` is a thin layer. When something fails, look at what it actually wrote:

```python
W.to_file()
print(open(f"{W.runpath}/ww3_grid.nml").read())   # the truth
W.run()
print(W.stdout)                                    # what WW3 said about it
print(W.stderr)
```

If the namelist looks right and WW3 still objects, the problem is your WW3 configuration,
not `pyww3`. Compare against `$WW3/model/nml/ww3_grid.nml`, which is the authoritative
annotated template.
