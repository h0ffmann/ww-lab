# Solutions

⚠ **These are reference implementations written from the pyww3 documentation, not from
executing them against a live WW3 build.** Treat them as worked examples of the *shape* of
the answer. Exact keyword names and defaults should be checked against the version of
`pyww3` you installed:

```python
from pyww3.grid import WW3Grid
help(WW3Grid)
```

and against the API reference: https://pyww3.readthedocs.io/en/latest/API.html

The pyww3 API is explicitly documented as unstable, so this is not paranoia.

## Working principle if a solution doesn't run

1. Print the namelist `pyww3` generated: `print(open(f"{run}/ww3_grid.nml").read())`
2. Diff it against the corresponding file in `examples/01-fetch-limited-growth/`
3. Diff *that* against `$WW3/model/nml/ww3_grid.nml`, the authoritative template
4. Fix the namelist by hand, confirm WW3 accepts it, *then* work out which Python keyword
   produces it

That loop is more valuable than any solution file.
