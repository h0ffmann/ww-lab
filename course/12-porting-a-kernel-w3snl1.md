# 12 — Porting a kernel: `W3SNL1`

Step 4 of the ladder, done once, end to end, on the routine lesson 07 nominated: the DIA
nonlinear interactions. Everything here is in `kokkos/`; keep it open. The phase-1 rule is
*translate, do not improve*: same expressions, same order, same float32 arithmetic. The
only thing that changes is who executes them (v, `kokkos/src/ww_kokkos/snl1_dia.cpp`).

## Source map

Source of truth: `WW3/model/src/w3snl1md.F90` at 7.14 `develop`. Line numbers (v, checked
in the clone at `~/src/WW3` and in the header of `kokkos/tests/fixtures/snl1_ref.F90`):

| Fortran | Lines | Sections | Port |
|---|---|---|---|
| `INSNL1` | 483–786; body 602–774 | 1 quadruplet angles · 2 lambda weights · 3 directional indices · 4 frequency indices · 5 ranges · 6 allocate (`W3DMNL`) · 7 spectral addresses · 8 `f**11` scaling · 9 interpolation weights | `snl1_tables.cpp`, `make_tables()` — host, once per grid |
| `W3SNL1` | 115–473; locals 305–326; body 338–440 | 1 propagation constant · 2 auxiliary spectrum and arrays · 3 interactions on the extended spectrum · 4 source and diagonal | `snl1_dia.cpp`, `snl1()` — device, per call |

The numbered comments in the C++ are the Fortran's own, so you can read the two side by
side (v). `snl1_config.hpp` names what both routines read from `W3GDATMD` (v).

## `Config` and `Tables`

`ww::snl1::Config` (v, `snl1_config.hpp`) is exactly the `W3GDATMD` inputs, under WW3's
names: `nk, nth, xfr, dth, lam, snlc1, kdcon, kdmn, snls1, snls2, snls3, fachfe`, plus
`nspec()`. `SIG` travels separately because `INSNL1` wants it on the host and `W3SNL1` on
the device (v). The constants `PI`, `TPI`, `TPIINV` are built the way `constants.F90` builds
them — `PI` rounded to `REAL` first, then doubled and inverted — because evaluating
`1/(2π)` in double and narrowing at the end is a different number by up to a ULP, and a
ULP is the whole budget of a parity test (v).

`ww::snl1::Tables` (v, `snl1_tables.hpp`) is `INSNL1`'s output: the scalars `nfr, nfrhgh,
nfrchg, nspecx, nspecy, nspec`, `dal1..3`, `awg[8]`, `swg[8]`, and 33 device Views —
`ip[2][4]` and `im[2][4]` of length `NSPECX`, `ic[8][2]` of length `NSPEC`, `af11` of
length `NSPECX`. Held as arrays of Views because that is how `W3SNL1` reads them, and
because a View is a copyable handle, so the whole struct is captured by value into the
kernel (v).

## Index conventions

| Fortran | Port | Why |
|---|---|---|
| `ISP = ITH + (IFR-1)*NTH`, all 1-based | `isp = ith + ifr*nth`, all 0-based | every table entry is the Fortran value minus one (v) |
| `IF3..IF6` clamped to 0 → addresses down to `1-NTH` | entries as low as `-NTH` are legal | `INSNL1` section 7 (v) |
| `UE(1-NTH:NSPECY)`, `SA1(1-NTH:NSPECX)` … | scratch of length `upper + NTH`; Fortran index `J` at slot `J-1+NTH`; a table entry `j` read at slot `j+NTH` | the `1-NTH` lower bound becomes slot 0 (v) |
| `A(NSPEC)` one point per call | `a(nspec, npts)` `LayoutLeft`, column `ip` is one contiguous spectrum | a batch of points per launch, memory a Fortran caller owns (v, `snl1_dia.hpp`) |

`L1_test_snl1_tables.cpp` has a test just for the window: every stored index must lie in
`[-nth, nspecy)` or `[-nth, nspecx)`, because an out-of-range read could pass the parity
test by luck (v).

## Kernel structure

One **team per sea point** (`TeamPolicy(npts, Kokkos::AUTO)`), because the working set —
an extended spectrum plus nine helper arrays — is per point and belongs in team scratch.
Scratch budget `(NSPECY + NTH) + 8·(NSPECX + NTH) + NSPEC` floats, checked against
`policy.scratch_size_max(0)` before the launch and thrown as `std::runtime_error` if it
does not fit (v). Inside the team (v):

1. **Section 1** — `CONS` from `KDMEAN`: three flops, recomputed by every thread rather
   than broadcast through scratch, cheaper than the barrier.
2. **Section 2** — `TeamThreadRange` over `nfr` fills `ue` and `con`; a second range
   zeroes slots `[0, NTH)` (the Fortran `DO ISP=1-NTH,0`); `team_barrier()`. Then the
   parametric tail `DO IFR=NFR+1,NFRHGH` stays **sequential** in `ifr` with a barrier
   per row, because row `IFR` reads row `IFR-1`.
3. **Section 3** — `TeamThreadRange` over `nspecx`: the four interpolated energies
   `EP1, EM1, EP2, EM2`, then `SA1, SA2, DA1C..DA2M`; `team_barrier()`.
4. **Section 4** — `TeamThreadRange` over `nspec` writes `s(isp, ipt)` and `d(isp, ipt)`.

No reduction anywhere: every output element is written by one thread from inputs no
thread modifies, so `WW_DETERMINISTIC` changes nothing and the result is bit-identical
across backends and thread counts (v). The launch is labelled `"srce.snl1.dia"` (v).

Two build facts decide whether "bit-identical" is true (v, `kokkos/src/ww_kokkos/CMakeLists.txt`
and `kokkos/README.md`):

- **Floating-point contraction is off** for `ww_kokkos`: `-ffp-contract=off`, and
  `--fmad=false` for the device half under nvcc. GCC's default fuses
  `AWG1*UE(..) + AWG2*UE(..)` into an FMA — one rounding where the Fortran does two —
  and `openmp-release` drifted 1.1e-5 relative from the fixture while `serial-debug` was
  bit-identical. With contraction off, all three presets reproduce the Fortran bit for bit.
  Removing that line is a physics change, not an optimisation.
- **`x**n` is not `std::pow`**: `powi()` and `pow11()` reproduce gfortran's
  multiplication chains.

## The shim and `W3KOKKOSMD`

`kokkos/src/fortran_iface/` is the boundary: `ww_kokkos_c.hpp` declares the C ABI,
`snl1_shim.cpp` implements it, `w3kokkosmd.F90` mirrors it in `ISO_C_BINDING` interface
blocks one for one (v).

| Entry point | Does |
|---|---|
| `int ww_kokkos_init(int comm_f)` | starts Kokkos if nobody has; idempotent; `comm_f` accepted and ignored in phase 1 (device from `WW_KOKKOS_DEVICE_ID`); reads `WW_KOKKOS_SNL1` |
| `void ww_kokkos_finalize(void)` | releases buffers; finalises Kokkos only if it started it |
| `int ww_snl1_init(nk, nth, xfr, dth, lam, snlc1, kdcon, kdmn, snls1, snls2, snls3, fachfe, sig)` | `make_tables` once per grid; `sig` copied, not borrowed |
| `void ww_snl1(npts, a, cg, kdmean, s, d)` | unmanaged `LayoutLeft` host views over the pointers, `deep_copy` into persistent device buffers grown on demand, kernel, `fence`, copy out; `npts == 0` is a legal no-op |
| `int ww_snl1_enabled(void)` | 1 iff `WW_KOKKOS_SNL1=1` at init |
| `int ww_snl1_last_error(void)` | status of the last call, 0 on success |

Three things a naive `extern "C"` wrapper gets wrong and this one does not (v,
`snl1_shim.cpp`): ownership of the runtime (a test's `::testing::Environment` may own it);
lifetime (a `push_finalize_hook` drops the Views inside `finalize`, never at process exit);
errors (nothing throws across the boundary — every entry is a `try`/`catch` that prints
one line and records a code). `W3KOKKOS_SETUP` turns `ww_snl1_enabled()` into
`LOGICAL :: KOKKOS_SNL1` once, so the model's inner loop reads a logical (v). Precision is
`REAL(C_FLOAT)` throughout; an `-r8` build needs a different ABI, not a kind change (v).
`kokkos/tests/L1_test_snl1_shim.cpp` exercises the raw C API on the fixture with poisoned
output buffers, so a forgotten copy-out fails loudly; `kokkos/tests/fixtures/shim_driver.F90`
is the same call from a Fortran program through `W3KOKKOSMD`.

## Fixtures

The L1 tests do not compare against numbers a human typed (v, `kokkos/tests/fixtures/README.md`):

| File | What |
|---|---|
| `snl1_ref.F90` | verbatim `W3SNL1`/`INSNL1` bodies; the only edits are the `USE` lines replaced by module variables with the same names, `CALL W3DMNL` replaced by the `ALLOCATE` it performs, and the `#ifdef W3_T*` output removed (v) |
| `gen_snl1_fixture.F90` | `SETUP_REF(25, 24, 1.1, 0.04118)` with ST4/NL1 defaults, a JONSWAP (10 m/s, 100 km, γ = 3.3) × cos² sea state in action form at 1000 m, 50 m and 10 m; streams header, tables and per-point `kdmean, cg, a, s, d` (v) |
| `snl1_nk25_nth24.bin` | the committed result, 107 892 bytes, little-endian, no record markers, tables stored 1-based exactly as Fortran holds them (v) |

The three depths exercise the `KDMEAN` branch: deep water where `EXP(X2)` underflows, and
a 7 % shallow-water correction at 10 m (v). `just snl1-fixtures` regenerates the file; a
byte-level diff then needs a reason in the commit message (v). `fixture_io.{hpp,cpp}` is
the one reader, and it subtracts one from every index (v).

## L1 tests and their tolerances

| Suite | Checks | Tolerance and why |
|---|---|---|
| `L1_test_snl1_tables` | all 32 address tables | exact — an address is an integer (v) |
| | `dal1..3`, `awg`, `swg`, `af11` | 1e-6 relative: they come out of `acosf`/`asinf`/`powf`, a ULP apart (v) |
| `L1_test_snl1_dia` | `S` and `D` on three points | 1e-5 relative with a 1e-30 absolute floor for denormal bins (v) |
| | zero spectrum → zero source; `A×2` → `S×8`, `D×4` | properties of the DIA, not of the fixture (v) |
| | four relaunches | bit-identical: a difference is a race, not rounding (v) |

Why 1e-5 for float32: the state has 24 bits, about 6e-8 relative, and section 3 forms
products of four-term interpolations scaled by `AF11` — a factor spanning ten decades —
so a handful of ULPs is the honest floor. 1e-5 is roughly two orders above that, and it is
*tight enough that one fused multiply-add fails it*: the FMA drift measured 1.1e-5. That
is the tolerance doing its job. `MatchesFortranReference` prints the max relative error it
saw, so a report can quote the number rather than "it passed" (v).

## The optional `ww3_lib` cross-check

`gen_snl1_ww3lib.F90` and `just l1-crosscheck` exist to prove `snl1_ref.F90` is a faithful
copy by running the *real* `W3SNL1` out of a configured WW3 build and `cmp`-ing the two
fixture files. **Neither has been run**: the WW3 build on the owner's host used `NL0`, so
`w3snl1md` is not in its `libww3.a`; the CMake guard detects that and skips the target.
It needs a WW3 built with an `NL1` switch, e.g. `just build switches/switch_lab_shrd` (v,
`kokkos/README.md`).

## `PATCH.md`: what changes in the WW3 caller

`w3kokkosmd.F90` is written to be dropped into `WW3/model/src` unchanged (v, its header).
The caller side is a documented patch, not applied in this repo
(`kokkos/src/fortran_iface/PATCH.md`, ⚠ written by the concurrent shim task): in
`w3srcemd.F90`, where `W3SNL1` is called under `#ifdef W3_NL1`, wrap the call in
`IF (KOKKOS_SNL1) THEN CALL WW_SNL1(…) ELSE CALL W3SNL1(…) END IF` behind
`#ifdef W3_KOKKOS`; `W3INIT` calls `WW_KOKKOS_INIT(-1)` and `W3KOKKOS_SETUP`; `KOKKOS`
joins `switches.json` and `src_list.cmake`; `ww_kokkos` is linked with `-DWW_KOKKOS=ON`.
Why the fork carries it: WW3's physics is frozen except for shims
(`docs/AGENTS_KOKKOS_202609.md` §5), and the lab pins WW3 as a submodule fork
(`just src-init`, `src-pr`, `src-sync` (v, `justfile`)), so the patch lives on a fork
branch that the pin can point at, and upstream stays untouched.

## L2: replay a regtest through both paths

```bash
just l2 ww3_ts1        # kokkos/tests/L2_replay.sh <ww3-dir> <regtest>
```

Requires `just rt <regtest>` done. The script copies `work_lab` to `work_a` and `work_b`,
runs `ww3_shel` with `WW_KOKKOS_SNL1=0` and `=1`, runs `ww3_ounf` in each, then
`nccmp-tol work_a/ww3.nc work_b/ww3.nc` with the default tolerances, and appends the table
to `kokkos/PORT_STATUS.md` under "L2 replays". Until the patch is applied on a fork
branch both runs are the Fortran path and the table shows zeros: that proves the harness,
not the kernel, and `PORT_STATUS.md` says so ("pending fork branch").

## The timing line

`kokkos/PORT_STATUS.md` is the ledger — one row per routine: WW3 file and lines, phase,
shim, L1 parity, L2 replay, Serial / OpenMP / CUDA ms per call, notes. The numbers come
from `ww_bench_snl1` (`kokkos/tests/bench_snl1.cpp`, not a test): 1 000 sea points, 20
calls, timed twice — through `ww_snl1()` with copy-in/copy-out, and on Views already on the
device. On a host backend the two are nearly equal; on CUDA the gap *is* the phase-1
transfer cost, the argument for phase 2. These are the numbers of the parity build: an
FMA-fused build would be faster and would not match the fixture (v).

## What "done" means

`docs/AGENTS_KOKKOS_202609.md` §1.5, which the course spec adopts: a port PR is complete
only with (1) the kernel with a heritage header naming the WW3 routine, (2) the `bind(C)`
shim and Fortran interface with the argument table, (3) an L1 test with tolerances stated
and justified, (4) an L2 replay of the smallest regtest that exercises it, (5) a timing
line in `PORT_STATUS.md`, (6) a property test where physics allows — for `Snl`, the cubic
scaling and zero tests stand in until an action-conservation test is written ⚠. Items
1–3 are in the tree, 5 is the ledger's `W3SNL1` row, 4 waits on the fork branch. Sheet:
`exercises/ex13_port.md`, solution `exercises/solutions/ex13_compare.sh`.

→ [`13-bulk-porting-with-agents.md`](13-bulk-porting-with-agents.md)
