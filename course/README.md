# The course

Ten lessons, in order. Roughly a weekend if you run everything, an evening if you read.

| | Lesson | You'll be able to |
|---|---|---|
| 00 | [Orientation](00-orientation.md) | Say what WW3 computes and what it doesn't. Name every program and what it writes. |
| 01 | [Getting it built](01-build.md) | Clone, fetch the data bundle, pick a switch, build with CMake, pass a regtest. |
| 02 | [Anatomy of a run](02-anatomy-of-a-run.md) | Write every namelist from scratch. Derive your own timesteps from the CFL condition. |
| 03 | [Grids, bathymetry, masks](03-grids.md) | Build a grid that isn't upside down, with the right sign on the depths. |
| 04 | [Forcing](04-forcing.md) | Get real winds in, and know the four ways `ww3_prnc` silently fails. |
| 05 | [Nesting and multi-grid](05-nesting.md) | Choose between one-way and `ww3_multi`, and place boundary points legally. |
| 06 | [Output and post-processing](06-output.md) | Get netCDF out, read spectra with `wavespectra`, partition sea from swell. |
| 07 | [Physics choices](07-physics-choices.md) | Choose a source-term package on purpose and know what you gave up. |
| 08 | [Driving WW3 from Python](08-python.md) | Script the whole pipeline; run sweeps instead of editing files. |
| 09 | [Performance and the RTX 4090](09-gpu-and-performance.md) | Know exactly why WW3 on a consumer GPU is a poor trade, and what to do instead. |

Do lesson 02 with `examples/01-fetch-limited-growth` open beside it. Do lesson 08 with
`exercises/` open. Lesson 09 stands alone and you can read it first if that's the question
that brought you here.
