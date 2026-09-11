# 01 — Getting it built

## Two halves

The WW3 package is **the git repo plus a binary data bundle**. The repo has the Fortran and
the regression-test *configurations*; the bundle has the bathymetry, forcing, and reference
output the tests need. The bundle lives on NOAA's FTP, not in git.

```bash
git clone --branch develop https://github.com/NOAA-EMC/WW3.git ~/src/WW3
cd ~/src/WW3
./model/bin/ww3_from_ftp.sh     # the other half. Slow. Required.
export WW3=$PWD
```

**Don't use the GitHub release tarball.** The newest tagged release is 6.07.1, from April
2019. Real work happens on `develop` and `main`, and the wider community is running v7.14.x.
Clone a branch.

## Dependencies

- Fortran 90 compiler — gfortran, ifort/ifx, nvfortran, or Cray
- **CMake ≥ 3.19**
- **NetCDF ≥ 4.1.1 with Fortran bindings.** The C library alone won't do; `ww3_ounf` and
  friends need `netcdf.mod`. On Debian/Ubuntu: `libnetcdff-dev`.
- MPI for anything realistic

`bash scripts/00_prereqs.sh` installs all of it on Debian/Ubuntu.

## The switch file

Before you build you pick a **switch file**: a whitespace-separated list of CPP keys that
selects the physics and the parallelism at compile time. See [`../switches/README.md`](../switches/README.md)
for a full annotated breakdown.

The consequence that matters: **changing the switch file requires a full rebuild.** Not
`make`, a full `rm -rf build`. The switch is baked into the preprocessed sources. "I turned
on ST4 and nothing changed" is nearly always a stale build directory.

## Build

```bash
cd $WW3
rm -rf build && mkdir build && cd build
cmake .. -DSWITCH=/abs/path/to/ww3-lab/switches/switch_lab_shrd
make -j$(nproc)
ls bin/
```

`-DSWITCH` takes either a bare name resolved inside `$WW3/model/bin/`, or an absolute path
to your own file.

Useful variants:

```bash
cmake --build . --target ww3_shel            # rebuild one program
cmake .. -DCMAKE_BUILD_TYPE=Debug -DSWITCH=… # bounds checking, backtraces
export NetCDF_ROOT=$(nf-config --prefix)     # if CMake can't find NetCDF
```

## Prove it works

```bash
bash scripts/03_run_regtest.sh $WW3 ww3_tp2.2
```

That script runs each program in turn and tees its stdout, rather than hiding everything
behind the `run_test` harness. Watch what each one prints. `ww3_grid` in particular emits a
long, genuinely useful summary of the grid it built and every namelist it read — always
keep it: `ww3_grid | tee ww3_grid.out`.

## Things that go wrong

| Symptom | Cause |
|---|---|
| `Cannot open include file 'netcdf.inc'` / undefined netCDF symbols | NetCDF Fortran bindings missing, or built with a *different* compiler. `.mod` files are compiler-specific and not interchangeable. |
| `ww3_ounf` runs but writes no `.nc` | `NC4` missing from the switch file. |
| `ww3_grid` demands an obstruction file you don't have | `FLAGTR` in `namelists.nml` isn't 0. |
| Model runs, output is all zeros | Forcing never arrived. Check `log.ww3` — it prints a per-timestep table showing which inputs updated. |
| Changed physics, nothing changed | Stale `build/`. `rm -rf build`. |
| Changed the grid, downstream programs behave oddly | Stale `mod_def.ww3`. Rerun `ww3_grid`. |
| `error reading input file` | `.inp` vs `.nml` mismatch. |

## Building with nvfortran

Possible and worth doing, but you must rebuild HDF5 and NetCDF with `nvfortran` first —
distro packages are gfortran-built and their `.mod` files are unusable. Details and a
realistic assessment in [`09-gpu-and-performance.md`](09-gpu-and-performance.md).

→ [`02-anatomy-of-a-run.md`](02-anatomy-of-a-run.md)
