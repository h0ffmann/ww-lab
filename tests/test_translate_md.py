import importlib.util, pathlib, unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("translate_md", ROOT / "scripts" / "translate_md.py")
tm = importlib.util.module_from_spec(spec); spec.loader.exec_module(tm)

SAMPLE = """# THEME

Text with `code`, formula $E = m c^2$ and a block:

```bash
just rt ww3_tp1.1
```

See [the repository](https://github.com/h0ffmann/ww3-gpu) and the citation [@ikuyajolu2023, p. 3].

$$\\frac{\\partial N}{\\partial t} = S$$

Table: A caption.

<!-- comment -->
"""


class Protect(unittest.TestCase):
    def test_round_trip_is_identity(self):
        masked, table = tm.protect(SAMPLE)
        self.assertEqual(tm.restore(masked, table), SAMPLE)

    def test_protected_content_is_hidden(self):
        masked, _ = tm.protect(SAMPLE)
        for s in ("`code`", "$E = m c^2$", "just rt", "https://github.com", "@ikuyajolu2023", "\\frac", "comment", "# THEME", "Table:"):
            self.assertNotIn(s, masked)
        self.assertIn("Text with", masked)

    def test_missing_placeholder_is_detected(self):
        masked, table = tm.protect(SAMPLE)
        broken = masked.replace("⟦0⟧", "")
        with self.assertRaises(tm.PlaceholderError):
            tm.restore(broken, table)

    def test_headings_localized(self):
        self.assertEqual(tm.localize_headings(["# THEME", "# References {-}"]), ["# TEMA", "# Referências Bibliográficas {-}"])
        with self.assertRaises(tm.PlaceholderError):
            tm.localize_headings(["# SOMETHING ELSE"])


if __name__ == "__main__":
    unittest.main()
