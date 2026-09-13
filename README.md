# wavewatch (III/IV) lab

A bootstrap repo for playing with **WAVEWATCH III** (WW3), NOAA/NCEP's third-generation
spectral wind-wave model. Built as a self-paced course: build the Fortran, run real cases,
drive it from Python, then poke at the GPU question.

---

## What's in here

| Path | What it is |
|---|---|
| `AWESOME-WW3.md` | Curated, annotated link list: source, docs, courses, tooling, papers, data, other models |
| `course/` | 12 lessons, in order, from "what is a wave spectrum" through GPUs, WAVEWATCH IV, and SWAN |
| `examples/` | Self-contained runnable cases with real `.nml` input files |
| `exercises/` | `pyww3` exercises (with solutions) — drive WW3 from Python |
| `gpu/` | nvfortran / OpenACC / CUDA Fortran sandbox aimed at your RTX 4090 |
| `bench/` | i9 vs 4090: a WW3-shaped kernel, a concurrent CPU+GPU split sweep, and real WW3 MPI scaling |
| `scripts/` | Get, build, and run WW3 (and SWAN); stage upstream regression tests |
| `switches/` | Annotated switch files (WW3's compile-time feature selection) |
| `env/` | conda environment + Dockerfile |

## Quickstart

```bash
# 0. host prerequisites (Debian/Ubuntu)
bash scripts/00_prereqs.sh

# 1. clone WW3 + fetch the binary test-data bundle from NOAA's FTP
bash scripts/01_get_ww3.sh ~/src/WW3

# 2. build with CMake using one of the lab switch files
bash scripts/02_build_ww3.sh ~/src/WW3 switches/switch_lab_shrd

# 3. smoke test against an upstream regression test
bash scripts/03_run_regtest.sh ~/src/WW3 ww3_tp2.2

# 4. run the first course example (fetch-limited growth, ~1 min)
cd examples/01-fetch-limited-growth && ./run.sh
```

Then start at [`course/00-orientation.md`](course/00-orientation.md).

Optionally, get SWAN too — it's the right tool for the coastal cases WW3 is wrong for:

```bash
bash scripts/04_get_swan.sh ~/src/swan
```

## Two things worth knowing before you invest

**WAVEWATCH IV exists, and WW3 is scheduled for sunset.** [NOAA-EMC/WW4](https://github.com/NOAA-EMC/WW4)
is a ground-up rewrite — new repository, no backward compatibility, C++ core with Rust
alongside, Fortran demoted to a solver-only language. As of 2026-09-11 it had 36 commits
and no releases: pre-alpha. First public release is hoped for summer 2027. The plan,
including the commitment to sunset WW3 support once WW4 matures, is in
[NCEP Office Note 525](https://doi.org/10.25923/h7j3-1h25). Learn WW3 anyway — the physics
is identical and the concepts transfer completely; only the interfaces won't. Details in
[`course/10-ww4-and-the-future.md`](course/10-ww4-and-the-future.md).

**SWAN is not a competitor, it's the other half of the toolkit.** Implicit,
unconditionally stable, no CFL limit, stationary mode. WW3 offshore, SWAN nearshore is the
standard coastal architecture. Source is now on
[TU Delft GitLab](https://gitlab.tudelft.nl/citg/wavemodels/swan), which most tutorials
haven't caught up with. See [`course/11-swan.md`](course/11-swan.md).

## The short answer on your RTX 4090

**Yes, NVIDIA ships a Fortran compiler.** It's `nvfortran`, part of the free
[NVIDIA HPC SDK](https://developer.nvidia.com/hpc-sdk). It does CUDA Fortran, OpenACC,
OpenMP target offload, and `do concurrent` offload (`-stdpar=gpu`). Your 4090 is Ada,
compute capability 8.9, so `-gpu=cc89`.

**But WW3 itself has no GPU support upstream**, and it never will — The only published port
([Ikuyajolu et al., GMD 2023](https://gmd.copernicus.org/articles/16/1445/2023/))
OpenACC-ified one module (`W3SRCEMD`, the source-term integration) and got roughly
**1.3× against 42 CPU cores** on Summit's V100s — data-transfer bound, and not merged
into `NOAA-EMC/WW3`. On a PCIe consumer card with no NVLink it will not be better. And WW4 is explicitly being
architected for GPUs from the ground up, which gives any heroic OpenACC work on WW3 a very
short shelf life.

So: compile WW3 with `nvfortran` on the **CPU** (that part works and is useful), use
`gpu/` to learn GPU Fortran on kernels that actually suit a 4090, and use `bench/` to
measure your own hardware rather than trusting anyone's table — including mine. Full reasoning and a
realistic experiment plan in [`course/09-gpu-and-performance.md`](course/09-gpu-and-performance.md).

## Conventions used in this repo

- `⚠` — I could not verify this; check it before trusting it.
- `(v)` — verified against a source I actually fetched while building this repo.
- Input files use the **namelist** (`.nml`) interface, not the legacy `.inp` fixed-format
  files. Both work in WW3 v7; `.nml` is far easier to read and is what `pyww3` targets.

## Repo layout notes

- `make help` lists the convenience targets.
- CI (`.github/workflows/ci.yml`) checks Python and shell syntax, compiles the Fortran
  sandbox with gfortran, and link-checks the markdown. It does not build WW3 — that needs
  the NOAA FTP data bundle and takes too long for a free runner.
- Before pushing: edit `LICENSE` to replace `<YOUR NAME>`.

## Licensing

MIT for everything in this repo. See [`LICENSE`](LICENSE).

WW3 itself is distributed by NOAA/EMC under its own terms. No WW3 source is vendored here —
`scripts/01_get_ww3.sh` clones it, and upstream regression-test inputs are fetched rather
than redistributed. Third-party tools listed in `AWESOME-WW3.md` carry their own licences
(`pyww3` is GPL-3.0, `wavespectra` is MIT).

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). The most useful contribution is confirming or
correcting anything marked `⚠`.
