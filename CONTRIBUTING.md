# Contributing

This is a personal learning repo. Corrections are very welcome, especially the
following, in order of usefulness:

1. **Anything marked `⚠`.** Those are places I could not verify a claim. If you
   have run it and know the answer, that's the highest-value fix in the repo.
2. **Namelists that don't actually work.** The `.nml` files here were written
   against the annotated upstream templates but not executed. If `ww3_grid`
   rejects one, please say which block and paste its stdout.
3. **Stale links in `AWESOME-WW3.md`.** Entries marked `(v)` were fetched on
   2026-09-11; unmarked ones are from memory and may be wrong.
4. **The wind direction convention in `examples/01`.** Deliberately left as an
   exercise, but a confirmed answer with the WW3 version you used is welcome.

## Ground rules

- Keep the `⚠` / `(v)` convention. Marking uncertainty honestly is the point.
- Don't vendor WW3 source. Scripts fetch it.
- Run `python -m compileall examples exercises` and `bash -n` on any shell
  script you touch. CI does both.
- Prose style: plain, direct, no filler. If a sentence doesn't teach something,
  cut it.
