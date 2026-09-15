# Contributing

This is a personal learning repo. Corrections are very welcome, especially the
following, in order of usefulness:

1. **Anything marked `⚠`.** Those are places I could not verify a claim. If you
   have run it and know the answer, that's the highest-value fix in the repo.
2. **Namelists that don't actually work.** The `.nml` files here were written
   against the annotated upstream templates but not executed. If `ww3_grid`
   rejects one, please say which block and paste its stdout.
3. **Stale links in `docs/AWESOME-WW3_202609.md`.** Entries marked `(v)` were fetched on
   2026-09-11; unmarked ones are from memory and may be wrong.
4. **The wind direction convention in `examples/01`.** Deliberately left as an
   exercise, but a confirmed answer with the WW3 version you used is welcome.
5. **WW4 status.** `course/14-ww4-and-the-future.md` quotes a repository snapshot from
   2026-09-11 and a timeline from NCEP Office Note 525. That will go stale faster than
   anything else here. Updates very welcome, with the date you checked.

## Ground rules

- Keep the `⚠` / `(v)` convention. Marking uncertainty honestly is the point.
- Don't vendor WW3 source. Scripts fetch it.
- Run `just kokkos-test serial-debug` after touching `kokkos/`, and `bash -n` plus
  shellcheck on any shell script you touch. CI does all of these (the `kokkos` and
  `lint` jobs in `.github/workflows/ci.yml`).
- Prose style: plain, direct, no filler. If a sentence doesn't teach something,
  cut it.

## Opening a pull request

Write the commit message properly (subject, a body paragraph saying what and why, and
`Tested:` / `Cost:` trailers in the final block of the message), then `just pr`: it pushes the branch and creates the PR with a description
generated from the commits (`just uprd` regenerates it later). A PR opened from the GitHub UI
gets the same treatment from `.github/workflows/pr-body.yml`. Delete the first `<!-- uprd -->`
line of a description to hand-edit it and keep it.
