# `kokkos/` — the C++/Kokkos half of the lab

One CMake tree, one backend per configure preset. It holds the portable kernel
library (`ww_kokkos`), the lesson-11 intro programs, the GoogleTest suites and the
C++ tools. The `W3SNL1`/DIA port itself lands in `src/ww_kokkos/` in a later task.

## Toolchain

Everything is built inside the pinned `nix-config/labs/pratico` shells — they are
what put Kokkos, GoogleTest, CMake, Ninja and NetCDF on the search path:

| shell | Kokkos backends | used by |
|---|---|---|
| `nix develop ./nix-config/labs/pratico#ww3` | Serial + OpenMP | `serial-debug`, `openmp-release`, CI |
| `nix develop ./nix-config/labs/pratico#cuda` | CUDA (ADA89) + Serial | `cuda-release`, this host only |

Pins: Kokkos 5.2.0, GoogleTest 1.18.0, CMake 4.4.2, gfortran 15.3.

## Layout

```
CMakeLists.txt        top level: options, find_package, the ww_kokkos target
CMakePresets.json     serial-debug, openmp-release, cuda-release
cmake/                CompilerWarnings.cmake -- the one warning policy
src/ww_kokkos/        real.hpp (float32 + helpers), spectrum_fixtures.hpp (JONSWAP, cos^2)
src/fortran_iface/    bind(C) interface module and shim          (Task 4)
intro/                01..06, one Kokkos concept each, each a CTest case
tests/                kokkos_env.hpp (runtime lifetime) + L1_* GoogleTest suites
tools/nccmp-tol/      per-field NetCDF comparator                (Task 5)
tools/bench_case/     benchmark-case generator                   (Task 6)
tools/fetch_analyse/  fetch-growth analyser                      (Task 6)
```

## Building

From the repository root:

```bash
just kokkos-test serial-debug     # configure + build + ctest
just kokkos-test openmp-release
just kokkos-cuda-test             # cuda-release, inside the #cuda shell
just kokkos-clean                 # rm -rf kokkos/build
```

Or directly, from this directory inside a pratico shell:

```bash
cmake --preset openmp-release && cmake --build --preset openmp-release && ctest --preset openmp-release
```

Builds land in `kokkos/build/<preset>/` (git-ignored).

## Presets

| preset | build type | notable |
|---|---|---|
| `serial-debug` | Debug | AddressSanitizer + UndefinedBehaviorSanitizer, `WW_DETERMINISTIC=ON` |
| `openmp-release` | Release | `-O3 -march=x86-64-v3` |
| `cuda-release` | Release | `CMAKE_CXX_COMPILER=nvcc_wrapper`, `CMAKE_CUDA_ARCHITECTURES=89` |

Two things the names do *not* promise:

- **The backend comes from the shell, not from the preset.** OpenMP is the default
  execution space in `#ww3`, so `serial-debug` is a *build type*, not a Serial-only
  build. Code that must run on Serial says `Kokkos::Serial` explicitly — see
  `intro/03_reduce_and_scan.cpp` and the last case in `tests/L1_test_intro.cpp`.
- **`Kokkos_ENABLE_DEBUG_BOUNDS_CHECK` cannot be set here.** It is an option of the
  Kokkos *build*, so it is fixed by the pinned Kokkos derivation in nix-config; a
  consumer project cannot turn it on. `serial-debug`'s safety net is the sanitizers.

`CMakePresets.json` uses presets schema version 10, which needs CMake ≥ 4.1.

## Options

| option | default | meaning |
|---|---|---|
| `WW_ENABLE_FORTRAN` | `ON` | build the Fortran interface module, reference and drivers (incl. `intro_06`) |
| `WW_DETERMINISTIC` | `OFF` | pin reductions to a fixed summation order for bit-reproducible validation runs |
| `WW_WW3_BUILD_DIR` | *(empty)* | a configured WW3 build (`libww3.a` + `mod/`); empty skips the WW3-linked targets |

## Intro programs

Each is a self-checking `main`: it prints one line and exits non-zero if the
concept it demonstrates does not hold, so CI runs the lesson material too.

| program | concept |
|---|---|
| `01_views` | `View` allocation, label, extents, `deep_copy` to a host mirror |
| `02_parallel_for` | `MDRangePolicy<Rank<2>>` + `parallel_reduce`, checked against a closed-form `m0` |
| `03_reduce_and_scan` | `Kokkos::MaxLoc` (value + location) and `parallel_scan` |
| `04_layouts_and_mirrors` | `LayoutLeft` vs `LayoutRight` strides, mirrors, unmanaged views |
| `05_team_scratch` | `TeamPolicy` + `team_scratch(0)`: the DIA kernel's extended spectrum |
| `06_interop_bindc` | `extern "C"` + Fortran `bind(C)`, borrowing a Fortran array |

## Tests

`tests/kokkos_env.hpp` starts the Kokkos runtime once per test binary from a
`::testing::Environment` (two OpenMP threads). `ww_add_test(<name>)` in
`tests/CMakeLists.txt` builds `<name>.cpp` and registers it with CTest.

Naming: `L1_*` are unit tests against analytic or captured-Fortran fixtures; `L2_*`
replay a whole WW3 regtest.

SPDX-License-Identifier: MIT
