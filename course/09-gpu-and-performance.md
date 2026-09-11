# 09 — Performance, and the RTX 4090 question

## Your question, answered directly

> I would like to try to run the WW3 fortran code on my RTX4090 (nvidia runs fortran, correct?)

**Yes, NVIDIA ships a production Fortran compiler.** It's `nvfortran`, part of the free
[NVIDIA HPC SDK](https://developer.nvidia.com/hpc-sdk) (descended from the PGI compilers
NVIDIA acquired). It supports Fortran 2003 and much of 2008, and offers four separate routes
to the GPU:

| Route | Flag | What it is |
|---|---|---|
| **OpenACC** | `-acc -gpu=cc89` | Directive-based. `!$acc parallel loop` on existing code. The lowest-friction way to port legacy Fortran. |
| **OpenMP target** | `-mp=gpu` | Same idea, different standard. `!$omp target teams distribute`. |
| **CUDA Fortran** | `-cuda` | Full control. `attributes(global)` kernels, `device` arrays, explicit `<<<grid,block>>>` launches. |
| **`do concurrent`** | `-stdpar=gpu` | Standard ISO Fortran, no directives at all. The compiler offloads `do concurrent` loops. Cleanest for new code. |

Your RTX 4090 is Ada Lovelace, **compute capability 8.9**, so `-gpu=cc89`. Consumer
GeForce cards work fine with `nvfortran` — you don't need a data-centre card. The SDK
bundles CUDA toolkit components but not the driver; `nvaccelinfo` tells you what driver
you have.

**But running WW3 itself on it is a different question, and the honest answer is no, not
usefully — yet.**

---

## Why WW3 on a GPU is hard

### There is no GPU support upstream

`NOAA-EMC/WW3` has no GPU code path. No `-acc` directives, no CUDA kernels, no
`do concurrent` offload. Building it with `nvfortran` produces a CPU binary.

### The one serious attempt got 1.3×

[Ikuyajolu, Van Roekel, Brus, Thomas, Deng & Sreepathi (2023), *Geoscientific Model
Development* 16, 1445–1462](https://gmd.copernicus.org/articles/16/1445/2023/) is the
reference. Read it before planning anything. Their findings, which you should treat as the
baseline expectation:

- They profiled WW3 and found `W3SRCEMD` — the source-term integration — dominates the
  cost. So that's what they offloaded, with OpenACC, keeping MPI for the rest.
- Tested on Kodiak and Summit (V100 GPUs), meshes of 59K and 228K nodes, 1–32 MPI ranks.
- **Speedup: about 1.3× against 42 CPU cores.** A 35–40% cut in wall time and
  resource-hours. Real, useful for a climate centre burning millions of node-hours — not
  the 10× people imagine when they hear "GPU".
- Packing 3 or 4 MPI ranks per GPU barely changed it.
- **The limiter is host↔device data-transfer bandwidth**, plus `W3SRCEMD` having so many
  local scalars and arrays that register pressure destroys occupancy.
- Using `!$acc routine` properly would help, but `W3SRCEMD` needs significant refactoring
  first — it isn't structured for it.
- Their broader point, stated plainly: GPUs need far more parallelism exposed *at one
  moment* than CPUs, and WW3's structure — global module variables, deep call chains,
  per-point source-term integration — fights that.
- **This work is not merged upstream.** ⚠ Check whether that's changed since early 2023.

### And WW3 is not where the GPU work is going

NOAA has decided the answer is architectural, not incremental. **WAVEWATCH IV** is a
ground-up rewrite whose stated drivers include, verbatim, that the rise of GPUs and other
advanced architectures requires focusing on memory use and access rather than only on
floating-point operations. WW4 Phase IV explicitly targets efficiency on CPUs *and* GPUs,
in a code designed for it from the start — new data structures local to each domain,
conventional domain decomposition instead of WW3's 2002-era "shuffle", and C++/Kokkos or
Rust instead of Fortran.

Which means any heroic OpenACC work you do on WW3 has a short shelf life. See
[`10-ww4-and-the-future.md`](10-ww4-and-the-future.md).

### Your hardware makes it worse, not better

The paper's bottleneck was PCIe/NVLink transfer on Summit nodes, which have **NVLink**
between CPU and GPU. You have PCIe 4.0 x16: roughly 32 GB/s, versus NVLink's 50–150 GB/s in
that generation. The thing that limited them is *more* limiting for you.

Also worth knowing about the 4090 specifically:

- **FP64 runs at 1/64 of FP32.** Roughly 1.3 TFLOP/s double precision against ~82 TFLOP/s
  single. That's a deliberate market-segmentation decision, not a defect. WW3 computes
  mostly in default (4-byte) real, so this may not bite you directly — but if anything in
  your build forces `-r8`, or if a library you link does, performance falls off a cliff.
  Check before you blame the port.
- **24 GB, no ECC.** Fine for a workstation-scale domain; a silent bit flip in a 72-hour
  hindcast is a real (if unlikely) thing.
- The 4090's actual superpower — enormous FP32/TF32/FP16 tensor throughput — is worthless
  to WW3, which does none of that.

### The structural problem

A WW3 state array is `nx × ny × nk × nth`. For a modest 81 × 81 grid with 32 frequencies
and 36 directions that's 7.5 million values *per field, per timestep*. The source-term
integration touches all of it, per sea point, per timestep, with an adaptive sub-timestep
loop (`DTMIN`) whose trip count varies by point. That's irregular, branchy, register-hungry
work over a big array — the opposite of what a GPU wants.

---

## What to do instead (in order)

### 1. Use the parallelism WW3 already has

This is the boring answer, and on a workstation it's the right one.

```bash
# build with switches/switch_lab_mpi  (DIST MPI)
mpirun -np $(nproc) ww3_shel
```

WW3's MPI uses "card-deck" domain decomposition over sea points, which balances well. On a
modern many-core desktop CPU this scales respectably out to your physical core count.
Adding `OMPG OMPH` to the switch enables OpenMP on top (hybrid), useful when MPI
decomposition gets too fine.

For unstructured grids with implicit schemes, WW3 has PDLIB + ParMetis decomposition
(v6.04+).

**Measure this first.** You need a CPU baseline before any GPU number means anything.

### 2. Build WW3 with nvfortran — on the CPU

Worth doing as a stepping stone. It validates the toolchain, and `nvfortran`'s CPU codegen
is competitive. The one real obstacle:

**Fortran `.mod` files are compiler-specific.** Your distro's `libnetcdff-dev` was built
with gfortran and `nvfortran` cannot read its modules. You must rebuild HDF5 and NetCDF
(C and Fortran) with `nvfortran` first. See [`../gpu/build_netcdf_nvfortran.sh`](../gpu/build_netcdf_nvfortran.sh)
for a sketch. The [WRF GPU port repo](https://github.com/FahrenheitResearch/wrf-gpu-port)
does the same thing and is a useful cross-reference for the pattern.

Then:
```bash
export FC=nvfortran CC=nvc CXX=nvc++
export NetCDF_ROOT=$HOME/opt/netcdf-nvhpc
cmake .. -DSWITCH=/path/to/switch_lab_shrd
```
⚠ Expect to fight it. WW3 is routinely built with gfortran and Intel; `nvfortran` is less
travelled and you may hit Fortran-standards pedantry the other compilers wave through.

### 3. Measure your own hardware first

Do not take my table of expectations, or anyone else's blog post, on faith.
[`bench/`](../bench/) has three benchmarks:

```bash
cd bench
make run                                     # WW3-shaped kernel: CPU vs GPU
python3 make_bench_case.py --size medium     # then the real model:
bash bench_ww3_cpu.sh $WW3/build case_medium #   MPI scaling on your i9
```

`kernel_bench` runs the same kernel twice — once with the spectrum resident on the device,
once copying it in and out each step. The gap between those two numbers *is* the reason
the published WW3 port only reached 1.3×, reproduced on your own PCIe bus in about a
minute.

`hetero_split` answers "can I use the CPU and GPU together?" by sweeping the work split
and reporting your optimum. See [`bench/README.md`](../bench/README.md) for the arithmetic
of why the answer is usually "yes, but it gains you almost nothing".

### 4. Profile before you port anything

```bash
nsys profile -o ww3_prof ./ww3_shel          # timeline
ncu --set full ./ww3_shel                    # kernel-level, once you have kernels
```
Or, without NVIDIA tooling at all: build with `-pg` and use `gprof`, or just add timers
around `W3SRCE`. Confirm on *your* configuration that source terms dominate. If your case
is propagation-heavy (large domain, weak forcing) the hot spot may be somewhere else, and
the published profile won't apply.

### 5. If you still want to port — the realistic plan

Start with the smallest thing that can possibly work:

1. Get [`gpu/`](../gpu/) working first. Confirm `nvfortran -acc -gpu=cc89` produces kernels
   that actually launch (`NVCOMPILER_ACC_NOTIFY=1` prints every launch).
2. Reproduce the paper's target: `W3SRCEMD`, OpenACC, one MPI rank per GPU.
3. **Use `-acc=multicore` as a correctness check.** Same directives, CPU threads instead of
   a GPU. If the answer changes between `multicore` and `gpu`, you have a data-movement
   bug, not a physics bug.
4. Manage data explicitly. `!$acc enter data copyin(...)` once, outside the timestep loop,
   not per call. The whole game is not moving the spectrum across PCIe every step.
5. Compare against a CPU reference run bit-for-bit where you can, statistically where you
   can't.

Budget: weeks, not an evening. And the published outcome on better hardware was 1.3×.

### 6. Point the 4090 at something it's actually good at

Your card is genuinely excellent hardware. Better uses, roughly in order of how much fun
they are:

- **[`gpu/`](../gpu/) in this repo.** Toy spectral kernels — DIA-like nonlinear transfer,
  dispersion solves, propagation stencils — written from scratch for the GPU. These *will*
  fly, because they're structured for it. You learn OpenACC and CUDA Fortran on problems
  where the answer is satisfying.
- **[Celeris](https://github.com/plynett/celeris_wavelab)** — a Boussinesq nearshore wave
  model built GPU-native, interactive, rendering in real time while it solves. If you want
  to *see* your GPU compute waves tonight, this is the thing. ⚠ verify the current repo URL.
- **[DualSPHysics](https://dual.sphysics.org/)** — SPH, written for CUDA from the start.
  Violent free-surface flows, breaking waves, structure impact.
- **FFT ocean surfaces (Tessendorf).** Take a real directional spectrum out of `ww3_ounp`,
  inverse-FFT it into an animated heightfield, render it. Physically it is the *same
  spectrum* WW3 computes — WW3 gives you its evolution, Tessendorf gives you one
  realisation of the surface. Wiring the two together is a genuinely good project and it
  will actually load your GPU.
- **ML wave emulators.** Training a surrogate on WW3 output is a dense tensor workload,
  which is exactly what the 4090's tensor cores exist for. This is the direction where
  consumer GPUs are transformative for wave modelling, rather than marginal.

---

## Quick reference: nvfortran

```bash
# install: https://developer.nvidia.com/hpc-sdk  (tarball or apt repo)
nvaccelinfo                      # driver + device check, prints your compute capability

nvfortran -acc -gpu=cc89 -Minfo=accel  prog.f90   # OpenACC, Ada target, tell me what you did
nvfortran -acc=multicore               prog.f90   # same directives, CPU threads (correctness check)
nvfortran -stdpar=gpu -gpu=cc89        prog.f90   # offload `do concurrent`, no directives
nvfortran -cuda -gpu=cc89              prog.cuf   # CUDA Fortran
nvfortran -mp=gpu -gpu=cc89            prog.f90   # OpenMP target offload

export NVCOMPILER_ACC_NOTIFY=1   # print a line per kernel launch
export NVCOMPILER_ACC_TIME=1     # per-kernel timing summary at exit
```

**`-Minfo=accel` is the one to internalise.** It tells you, line by line, which loops were
parallelised and — much more importantly — which weren't and why. "Loop not vectorized:
data dependency" or "Accelerator restriction: call to procedure with no acc routine" is the
compiler telling you exactly what to fix. Most OpenACC work is reading `-Minfo` output and
responding to it.

---

## Realistic performance expectations, summarised

| Approach | Expected on your box |
|---|---|
| Serial `ww3_shel` | baseline |
| MPI over all physical cores | near-linear to your core count. **Do this.** |
| MPI + OpenMP hybrid | marginal over pure MPI at this scale |
| `nvfortran` CPU build | comparable to gfortran, maybe a little better |
| Offloading `W3SRCEMD` to the 4090 | ⚠ optimistically ~1.3× vs a many-core CPU, per the published result on better-connected hardware. Weeks of work. Quite possibly slower. |
| Custom GPU kernels in `gpu/` | 10–50× on the right kernel. Educational, not WW3. |
| Waiting for WW4 | Architected for GPUs. First public release hoped summer 2027. |

## Sources for everything above

- Ikuyajolu et al. (2023), *GMD* 16, 1445–1462 — https://gmd.copernicus.org/articles/16/1445/2023/
- NVIDIA HPC SDK docs (26.5) — https://docs.nvidia.com/hpc-sdk/
- OpenACC Getting Started Guide — https://docs.nvidia.com/hpc-sdk/compilers/openacc-gs/
- `do concurrent` offload — https://developer.nvidia.com/blog/accelerating-fortran-do-concurrent-with-gpus-and-the-nvidia-hpc-sdk/
- cc89 = RTX 4090 confirmed in https://github.com/FahrenheitResearch/wrf-gpu-port (third-party)
- NCEP Office Note 525, Tolman (2025) — https://doi.org/10.25923/h7j3-1h25

→ [`10-ww4-and-the-future.md`](10-ww4-and-the-future.md), or start playing in
[`../gpu/`](../gpu/).
