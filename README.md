# wavewatch lab - III & IV

A bootstrap repo for playing with **WAVEWATCH III** (WW3), NOAA/NCEP's third-generation
spectral wind-wave model. Built as a self-paced course: build the Fortran, run real cases,
drive it from Python, then poke at the GPU question.

---

## What's in here

| Path | What it is |
|---|---|
| `course/` | 12 lessons, in order, from "what is a wave spectrum" through GPUs, WAVEWATCH IV, and SWAN |
| `examples/` | Self-contained runnable cases with real `.nml` input files |
| `exercises/` | `pyww3` exercises (with solutions) — drive WW3 from Python |
| `gpu/` | nvfortran / OpenACC / CUDA Fortran sandbox aimed at your RTX 4090 |
| `bench/` | i9 vs 4090: a WW3-shaped kernel, a concurrent CPU+GPU split sweep, and real WW3 MPI scaling |
| `scripts/` | Get, build, and run WW3 (and SWAN); stage upstream regression tests |
| `switches/` | Annotated switch files (WW3's compile-time feature selection) |
| `env/` | conda environment + Dockerfile |
| `docs/` | [`AWESOME-WW3_202609.md`](docs/AWESOME-WW3_202609.md), a curated link list; [`AGENTS_KOKKOS_202609.md`](docs/AGENTS_KOKKOS_202609.md), agent rules for a phased WW3 → Kokkos port; [`KOKKOS_H100_PLAN_202609.md`](docs/KOKKOS_H100_PLAN_202609.md), the single-H100 port plan |
| `nix-config/` | Git submodule (sparse: only `labs/pratico`) — the pinned Nix toolchain WW3 is built with |
| `WW3/` | Git submodule — the [h0ffmann/WW3](https://github.com/h0ffmann/WW3) fork of NOAA-EMC/WW3, with upstream as a second remote |
| `pubs/` | Publications: the course book and the UFRJ/DEL project proposal (EN source, PT generated); PDFs land in `pdf/` on `main` |
| `justfile` | Every task in this repo: `just` lists them |

## Quickstart

Needs [Nix](https://nixos.org) and [just](https://github.com/casey/just); the compilers come
from the pinned flake (next section), nothing else to install.

```bash
git clone --recurse-submodules git@github.com:h0ffmann/ww-lab.git && cd ww-lab
just submodule-init   # sparse-checkout nix-config (once per clone)
just get              # clone upstream NOAA-EMC/WW3 develop into ~/src/WW3
just rt               # build with ww3_tp1.1's own switch and run that regtest (~30 s)
just build            # rebuild with the lab switch (switches/switch_lab_shrd, ST4 physics)
just example01        # first course example: fetch-limited growth (~1 min)
```

Then start at [`course/00-orientation.md`](course/00-orientation.md). Every recipe is a thin
wrapper over a script in `scripts/`; run those directly if you prefer a host toolchain
(`just prereqs` installs it on Debian/Ubuntu).

Optionally, get SWAN too — it's the right tool for the coastal cases WW3 is wrong for:

```bash
just swan             # clone and build into ~/src/swan
```

## Nix toolchain (reproducible gfortran / OpenMPI / NetCDF)

Instead of `scripts/00_prereqs.sh`, the compilers and libraries can come from one locked
nixpkgs revision via the [`nix-config/labs/pratico`](https://github.com/h0ffmann/nix-config/tree/main/labs/pratico) flake, which
lives in `nix-config`, a sparse git submodule. A `justfile` at the repo root wraps it:

```bash
just up          # bump the submodule pin to origin/main and stage it  (just st = status)
just ww3         # enter the toolchain-only shell  (== nix develop ./nix-config/labs/pratico#ww3)
just ww3-run …   # run one command inside that shell, e.g. just ww3-run gfortran --version
just toolchain   # exact pinned versions
just smoke       # Fortran 2008 + MPI + NetCDF-4 build-and-run in the Nix sandbox
```

Build and run WW3 itself in that shell. The source tree is `$WW3`, else `~/src/WW3`, the
plain upstream NOAA-EMC clone; pass `WW3` as the last argument to use the fork submodule:

```bash
just get                 # clone upstream develop into ~/src/WW3 (WW3_DATA=1 to also fetch the FTP bundle)
just rt                  # the simple regtest: build with ww3_tp1.1's own switch, run it (~30 s on 32 cores)
just rt ww3_tp2.2 PR3_UQ # another test / switch_<sw> from its input/ dir;  ... PR3_UQ WW3 = on the fork
just build [switch]      # full rebuild with a switch file (default switches/switch_lab_shrd)
just regtest [test]      # rerun a test step by step against the current build (no rebuild)
```

`ww3_tp1.x` and `ww3_tp2.2` need no FTP data. Output lands in `<ww3>/regtests/<test>/work_lab/`;
for `ww3_tp1.1` the gridded `ww3.196806.nc` should show `hs` starting at 2.5 m on the equator row.

What `just toolchain` prints today (`(v)` — this is the exact output on the lab machine):

```
$ just toolchain
ww3 toolchain: GNU Fortran (GCC) 15.3.0 | mpirun (Open MPI) 5.0.10 | netcdf-c 4.10.1 / netcdf-fortran 4.4.6-development
nixpkgs      eaad089433ca2bb662274377d33df3d0e51ef28b
gfortran     GNU Fortran (GCC) 15.3.0
openmpi      mpirun (Open MPI) 5.0.10
netcdf-c     netCDF 4.10.1
netcdf-f     netCDF-Fortran 4.4.6-development
hdf5         h5dump: Version 1.14.6
metis        /nix/store/kakzikafyrpx9pp49kxxgmjvvnymm6vr-metis-5.2.1
parmetis     /nix/store/rdkv3jg7b52dw0qlkwx9f1aihjsm7xwb-parmetis-4.0.3-unstable-2023-03-26
eccodes      2.48.0
cmake        cmake version 4.4.2
python       Python 3.14.7 numpy 2.5.1 xarray 2026.7.0
```

The `warning: Git tree '…/nix-config' has uncommitted changes` line Nix prints is the
sparse checkout, not real edits; `git -C nix-config status` is clean.

The `WW3/` submodule is your fork, kept in step with upstream by `just src-sync`
(`just src-st` shows pinned vs. fork vs. upstream). Pass `WW3` as the last argument of
`build`, `regtest` or `rt` to build the fork instead of `~/src/WW3`.

## Publications (markdown → PDF)

The toolchain (pandoc, TeX Live, Python) comes from
[`nix-config/labs/publisher`](https://github.com/h0ffmann/nix-config/tree/main/labs/publisher), which
the root `flake.nix` consumes through its `mkPdf` helper; `nix build .` produces every PDF in a
sandbox and CI commits them to `pdf/` on `main`.

```bash
just book                 # course/*.md -> build/ww3-lab-course.pdf (one chapter per lesson)
just proposal en          # pubs/proposal/en/*.md -> build/proposal_en.pdf (DEL proposal layout)
just proposal pt ieee     # Portuguese copy; second arg picks the citation style: abnt (default) | ieee
just translate            # pubs/proposal/en -> pt via any OpenAI-compatible endpoint (changed files only)
just pubs                 # all three
```

The proposal is written in English under `pubs/proposal/en/`; `pubs/proposal/pt/` is generated
and overwritten, so edit the English or the translator's prompt, never the Portuguese. The DEL
section names are a fixed glossary in `scripts/translate_md.py`. Header fields (student, advisors,
date) live in `pubs/proposal/meta.{pt,en}.yaml`. The LaTeX layout is the department's own
proposal template (`pubs/proposal/template.tex`, styles under `pubs/proposal/shared/`).

Translation backend: set `TRANSLATE_BASE_URL`, `TRANSLATE_API_KEY` and `TRANSLATE_MODEL`
(locally, `http://127.0.0.1:11434/v1` / `ollama` / an Ollama model works; in CI the same three
names as repository secrets, otherwise the step is skipped and the committed `pt/` is used).

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

**But WW3 itself has no GPU support upstream**, and it never will — the only published port
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

- `just` lists every task; `justfile` is the entry point, `scripts/` holds the logic.
- CI (`.github/workflows/ci.yml`) checks Python and shell syntax, compiles the Fortran
  sandbox with gfortran, and link-checks the markdown. It does not build WW3 — that needs
  the NOAA FTP data bundle and takes too long for a free runner.

## Licensing

MIT for everything in this repo. See [`LICENSE`](LICENSE).

WW3 itself is distributed by NOAA/EMC under its own terms. No WW3 source is vendored here —
`scripts/01_get_ww3.sh` clones it, and upstream regression-test inputs are fetched rather
than redistributed. Third-party tools listed in `docs/AWESOME-WW3_202609.md` carry their own licences
(`pyww3` is GPL-3.0, `wavespectra` is MIT).

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). The most useful contribution is confirming or
correcting anything marked `⚠`.
