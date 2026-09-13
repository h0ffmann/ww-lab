# SCOPE

The work is limited to the single-grid driver of WW3 (`ww3_shel`) in the configuration operated by LabECO: its grid, its switch file, its forcing and its output list. That configuration is frozen at the start of the project and documented in a configuration record, together with the pinned source revision of the model, so that every measurement refers to the same code and the same case.

Four rungs are in scope, attempted in order and each gated by a comparison against the frozen reference run:

1. **Build options.** Compiler, optimisation flags, the switch file (in particular the choice between shared-memory, MPI and hybrid builds, and the NetCDF-4 output path), and the MPI and OpenMP layout on the available nodes. This rung changes no source code and is expected to be bit-for-bit reproducible against the reference or, when floating-point reordering is involved, within round-off.
2. **Run configuration.** Domain decomposition, time steps allowed by the CFL condition, output frequency and output fields, restart strategy, and forcing interpolation. This rung changes namelist inputs only.
3. **Targeted modern-Fortran refactoring.** Rewriting of the routines that the profile identifies as dominant, typically the source-term integration (`W3SRCE`) and spatial propagation, using standard Fortran 2008/2018 constructs (`do concurrent`, explicit interfaces, contiguous arrays, elimination of large automatic arrays) without altering the numerical algorithm. Results must match the reference within a tolerance defined per output field.
4. **GPU feasibility on an NVIDIA H100.** A study, not a port: which kernels could run on the device, what data would have to reside there, and what speed-up is plausible, informed by the published attempts on WW3 and on the WAM model, and by a small prototype of one kernel. The outcome is a written recommendation with measurements, not an operational GPU build.

Out of scope are the multi-grid driver (`ww3_multi`), coupling to atmosphere or ocean models, data assimilation, unstructured grids with implicit solvers (PDLIB) unless the operational grid requires them, changes to the physics parameterisations, and any contribution to or dependence on the WAVEWATCH IV project, which is discussed in the justification below.
