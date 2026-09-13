# 10 — WW4: what's coming, and how mature it is

**Short version: WW4 is real, it is a full ground-up rewrite in C++ and Rust rather than a
new WW3 version, and as of late 2026 it is pre-alpha. Learn WW3. Watch WW4.**

## It exists

- Repository: **[NOAA-EMC/WW4](https://github.com/NOAA-EMC/WW4)** `(v)` —
  "Home of the WAVEWATCH IV ™ (WW4 ™) third-generation wind wave modeling framework"
- Planning document: **NCEP Office Note 525**, *The WAVEWATCH III® Software Modernization
  Project: Phase I report*, Hendrik L. Tolman, November 2025.
  [doi:10.25923/h7j3-1h25](https://doi.org/10.25923/h7j3-1h25) `(v)`

Office Note 525 is the single best thing to read if you want to understand where wave
modelling is going. It is unusually candid — it publishes the disagreements inside the
discussion group rather than papering over them.

## Maturity: a snapshot

Checked against the repository on **2026-09-11** `(v)`:

| Signal | Value |
|---|---|
| Default branch | `develop` |
| Commits | 36 |
| Releases / tags | **none** |
| Stars / forks / watchers | 3 / 7 / 4 |
| Open issues / PRs | 34 / 1 |
| Top-level dirs | `src/ tests/ tools/ templates/ externals/` |
| Build | `CMakeLists.txt` |

Thirty-six commits and no release. This is scaffolding and early core work, not a model you
can run. Treat it as a project to follow, not a tool to adopt.

⚠ Those numbers were true on one day. Check them yourself before quoting them — that's
exactly the kind of thing that goes stale fastest.

## Why a new model rather than WW3 v8

The Phase I report lays out the drivers plainly:

- **Parallel concepts are 24 years old.** WW3 uses a "shuffle" method for distributed
  computing (Tolman 2002a) that load-balances dynamic source-term timestepping beautifully
  but doesn't scale to exascale. WW4 moves to conventional domain decomposition.
- **Data structures are rooted in the Fortran 90 transition** of nearly two decades ago.
  WW4 wants spatial data structures local to each domain, for scalability and a smaller
  memory footprint — and for source-term integration over *areas* rather than individual
  grid points.
- **Optimisation now means memory, not FLOPs.** The report says this directly: the rise of
  GPUs and other advanced architectures requires focusing on memory use and access,
  complementing the traditional focus on floating-point operations. (See lesson 09 — this
  is the institutional version of the same conclusion.)
- **Fractional stepping fights implicit schemes.** WW3's architecture leans on fractional
  steps (Yanenko 1971), which works beautifully for explicit propagation and badly for the
  implicit unstructured-grid solvers everyone now wants.
- **Closer coupling.** UFS wants component models callable at the level of functional
  units, not wrapped as monoliths. That needs an object-oriented interior.
- **The Fortran compiler pool is shrinking.** Stated as a continuity-of-operations risk:
  NWS wants to move off Fortran *in a controlled way, before it becomes urgent*.
- **Regression testing has become unsustainable.** Recompiling between individual tests is
  called out as untenable. WW4 moves to unit and integration testing.

The decision was a **complete bottom-up rewrite in a new repository**, explicitly modelled
on how NOAA handled MOM6 (developed separately from MOM4 rather than as an increment).
A new repo removes the obligation of backward compatibility and allows "house cleaning" of
options that no longer have an owner.

## Languages — the contentious part

The report says outright that language choice was the most contentious question, and that
**there is no community consensus**. NOAA/NWS made the call as primary funder:

| Language | Role in WW4 |
|---|---|
| **C++** (likely with Kokkos) | Initial **core** language. Conservative, proven, operational centres already have the workforce. Can be end-to-end. |
| **Rust** | Named "the modern language of choice for WW4" by NOAA/NWS, for memory safety, fearless concurrency, and lower porting/O&M cost. Being built in parallel with C++. |
| **Fortran** | **Solver language only**, plus a fast route to an initial operational capability. Also where unowned legacy options stay. |
| **Python** | Scripting, workflow, data management, product generation, grid generation, graphics. **Explicitly not** a core or solver language — the report cites C++/Kokkos outperforming Python/GT4Py on GPUs. |
| **Julia** | Considered and **declined** as a core language by NOAA/NWS: small user community, partial memory-safety benefit, workforce risk. Still permitted for non-operational solvers. |

The chosen path is the **"dual approach"**: build a C++ core to an operations-ready state
in roughly two years, while incrementally building Rust alternatives; a Rust-cored WW4 for
operations is a roughly five-year target.

A design principle worth noting, because it's the thing that would let you contribute:
WW4 is deliberately keeping a **clean separation between core and solver code**, with
language bindings between them — so a contributor writing a new source-term
parameterisation can do it in whichever language they're fluent in without learning the
core language.

## Yes, it is being written partly by AI agents

The WW4 repository contains an `AGENTS.md` describing "an agentic AI approach used to
create, translate or refactor code using AI agents such as Copilot or Jules, the latter of
which has been used extensively in developing the WW4 code from WW3." `(v)` The agent is
also set up to enforce coding standards, generate doxygen documentation, and write unit
tests, all of which are mandated for WW4.

Worth knowing, for two reasons. It's a large, visible, government-operational test of
AI-assisted translation of scientific Fortran. And it means the provenance of any given
line in WW4 is a live question you should keep in mind when reading it.

## Timeline

From Office Note 525 `(v)`, with the report's own caveat that timelines for a project like
this are notoriously difficult:

| Phase | What | When |
|---|---|---|
| I | Initial choices | complete (this report) |
| II | Language test, governance setup, architecture design | began 1 Oct 2025, 3–6 months |
| III | Core code development (EMC) | open source, not yet open contribution |
| IV | **Initial Model Capability** — single domain, CPU *and GPU* efficiency focus | **active community engagement expected summer/autumn 2026** |
| V | Initial Operational Capability — multi-domain | |
| VI | Complete first full code | **first public release hoped for summer 2027** |

Those dates are for the C++ path. Rust may take up to five years.

⚠ We are now past the "summer or fall of 2026" mark for Phase IV. Check the repo's
activity, Discussions, and issue tracker to see whether that actually happened.

## What this means for WW3 — and for you

**WW3 is not going away soon, but its end is now scheduled.** The report is explicit: the
cost of maintaining two models long-term will be mitigated by "formally sunsetting most
support for WW3 once WW4 is mature, with a clearly communicated transition period." Code
with no identified owner willing to port it stays in WW3 and is considered obsolete for
WW4.

Practically:

- **Learn WW3 now.** It is the mature, documented, validated, operational model, and it
  will be for years. Everything in this repo remains the right thing to learn.
- **The concepts transfer completely.** The action balance equation, source-term packages,
  spectral discretisation, CFL limits, grids, nesting, partitioning — none of that changes.
  WW4 is a software rewrite, not new physics.
- **The interfaces will not transfer.** Expect namelists to go (the report canvasses ASCII
  / YAML / namelist and notes the choice follows from the language), expect the binary
  `mod_def.ww3` / `out_grd.ww3` files to go (consensus to move to NetCDF, with interest in
  Zarr), and expect the compile-time switch file to be reconsidered — the pushback from
  researchers about recompiling between runs is recorded in the report.
- **The separate-executables workflow is under review.** `ww3_grid` / `ww3_prep` /
  `ww3_shel` / `ww3_ounf` as distinct programs is explicitly listed as a design decision
  to revisit.
- **If you were going to GPU-port WW3 yourself: don't.** WW4 Phase IV targets CPU *and*
  GPU efficiency in a code architected for it from the start. Any heroic OpenACC work on
  WW3 now has a short shelf life. See lesson 09.

## One thing that must survive

The report singles out a property of WW3 that WW4 has to keep: **full numerical convergence
of its schemes**, achieved through the limiter formulation of Tolman (2002b). Without it
you cannot separate numerical error from physical error, which makes the model useless for
science. It's a good reminder that "modernisation" has constraints that aren't about
software at all.

→ [`11-swan.md`](11-swan.md) — the other model you should know.
