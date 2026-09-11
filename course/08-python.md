# 08 — Driving WW3 from Python

## The landscape

| Tool | Role |
|---|---|
| [`pyww3`](https://github.com/caiostringari/pyww3) | Generate namelists from typed dataclasses and run the WW3 executables. Thin and honest. |
| [`WW3-tools`](https://github.com/NOAA-EMC/WW3-tools) | NOAA's official post-processing and validation: altimeter, buoys, statistics, plots. |
| [`wavespectra`](https://github.com/wavespectra/wavespectra) | The xarray library for spectral data. Reading, partitioning, statistics, polar plots. |
| [`ww3tool`](https://pypi.org/project/ww3tool/) | More ambitious wrapper: namelists + run scripts + Slurm submission + plotting. Young. |
| [`bmi-wavewatch3`](https://pypi.org/project/bmi-wavewatch3/) | Download NOAA's *published* WW3 hindcasts as xarray. Not for running the model. |
| [`rompy`](https://github.com/rom-py/rompy) | General pydantic-validated ocean-model configuration. Strong SWAN/SCHISM plugins; ⚠ no WW3 plugin found. |

## pyww3

The design is simple enough to hold in your head:

- Every WW3 program gets a dataclass — `WW3Grid`, `WW3Prnc`, `WW3Shel`, `WW3Ounf`,
  `WW3Ounp`, `WW3Bounc`.
- Every namelist parameter becomes a constructor keyword, with the `%` flattened to `_`.
  `SPECTRUM%FREQ1` → `spectrum_freq1`, `TIMESTEPS%DTMAX` → `timesteps_dtmax`.
- Validation happens in `__post_init__`: it checks required files exist and that values
  are compatible with the namelist definitions.
- All classes inherit `WW3Base`, which provides:
  - `populate_namelist()` — build the namelist text
  - `to_file()` — write it into `runpath`
  - `run()` — execute the program there, capturing `stdout`/`stderr`
  - `update_text(block, action=…)` — surgically add or remove a namelist block

That last one exists because the generated namelist contains every block, and `ww3_grid`
objects to blocks it doesn't need. Hence the idiom from the docs:

```python
W.update_text("&SED_NML",   action="remove")
W.update_text("&SLOPE_NML", action="remove")
W.update_text("&CURV_NML",  action="remove")
W.update_text("&UNST_NML",  action="remove")
```

And the gotcha that follows from it: **after you mutate an attribute, you must regenerate
the text.**

```python
W.timesteps_dtmax = 1440.
W.text = W.populate_namelist()   # <- without this, to_file() writes the OLD value
W.to_file()
```

### Minimal end-to-end

```python
import datetime
from pyww3.shel import WW3Shel

W = WW3Shel(
    nproc=8,
    runpath="runs/experiment_01/",
    mod_def="runs/experiment_01/mod_def.ww3",
    domain_start=datetime.datetime(2024, 7, 1, 0),
    domain_stop=datetime.datetime(2024, 7, 8, 0),
    input_forcing_winds=True,
    date_field_stride=3600,
    date_point_stride=3600,
    date_restart_stride=3600,
    type_point_file="runs/experiment_01/points.list",
)
W.to_file()   # writes ww3_shel.nml
W.run()
print(W.stdout)
```

### The honest assessment

The author's own words: *work in progress, API not stable, use at your own risk.* It's a
small project with a handful of stars. **Use it anyway, for learning**, because:

- It's a thin layer. You can always print the namelist it generated and read it.
- Being forced to name every parameter in Python teaches you the namelist faster than
  copying `.nml` files does.
- Once you understand it, writing your own generator for whatever you actually need is a
  two-hour job.

What it doesn't do: ASCII-input programs (`ww3_outf`, `ww3_strt`, `ww3_multi`). For those,
write the file yourself.

### If pyww3 doesn't fit

The namelist format is trivially templatable. Jinja2 plus a YAML config gets you 80% of a
wrapper in an afternoon, with the advantage that you control it:

```python
from jinja2 import Template
import yaml, subprocess, pathlib

cfg = yaml.safe_load(open("config.yml"))
for prog in ("ww3_grid", "ww3_shel", "ww3_ounf"):
    tpl = Template(pathlib.Path(f"templates/{prog}.nml.j2").read_text())
    pathlib.Path(f"{run}/{prog}.nml").write_text(tpl.render(**cfg))
    subprocess.run([prog], cwd=run, check=True)
```

This is, roughly, what `rompy` does properly, with pydantic validation instead of hope.

## Work through the exercises

[`../exercises/`](../exercises/) has six graded exercises using `pyww3`, with solutions.
They rebuild `examples/01` from Python and then go beyond it into parameter sweeps and
spectral analysis.

→ [`09-gpu-and-performance.md`](09-gpu-and-performance.md)
