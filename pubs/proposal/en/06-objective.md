# OBJECTIVE

The general objective is to reduce, in a measured and reproducible way, the wall-clock time of the operational WAVEWATCH III cycle run by LabECO/UFSC within ReNOMO, without changing its scientific results beyond tolerances agreed with the laboratory, and to deliver a written recommendation on how far the laboratory's hardware, including an NVIDIA H100, can take that reduction.

The specific objectives are:

1. To freeze and document the operational configuration (source revision, switch file, namelists, grid, forcing, outputs, hardware) and to build a reproducible benchmark of the reference run, with a defined metric (wall-clock per forecast hour and spectral bin updates per second).
2. To produce a profile of the reference run by routine and by phase (source terms, propagation, gather/scatter communication, I/O), on one and on several MPI ranks.
3. To quantify the gain of each rung of the optimisation ladder, build options, run configuration and targeted refactoring, each with its parity evidence against the reference, and to deliver the best configuration to the laboratory as a documented build.
4. To assess the feasibility of GPU execution on an H100 through a study and a single-kernel prototype, reporting measured numbers and the data-movement constraints that bound them.
5. To publish the tooling, the results and the recommendation in the open repository, in a form that the laboratory can rerun and that the WW4 developers can consult.
