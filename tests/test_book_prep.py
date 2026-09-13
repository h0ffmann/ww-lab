import pathlib, subprocess, sys, tempfile, unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "book_prep.py"


class BookPrep(unittest.TestCase):
    def run_prep(self, files):
        src = pathlib.Path(tempfile.mkdtemp()); out = pathlib.Path(tempfile.mkdtemp())
        for name, text in files.items():
            (src / name).write_text(text)
        p = subprocess.run([sys.executable, SCRIPT, src, out], capture_output=True, text=True)
        return p, out

    def test_ids_and_links(self):
        p, out = self.run_prep({
            "00-orientation.md": "# Orientation\n\nSee [grids](03-grids.md) and [dx](03-grids.md#resolution).\n",
            "03-grids.md": "# Grids\n\n## Resolution\n",
            "README.md": "# not a chapter\n",
        })
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(sorted(x.name for x in out.iterdir()), ["00-orientation.md", "03-grids.md"])
        text = (out / "00-orientation.md").read_text()
        self.assertIn("# Orientation {#ch-orientation}", text)
        self.assertIn("[grids](#ch-grids)", text)
        self.assertIn("[dx](#resolution)", text)

    def test_dangling_link_fails(self):
        p, _ = self.run_prep({"00-a.md": "# A\n\n[x](09-missing.md)\n"})
        self.assertEqual(p.returncode, 1)
        self.assertIn("09-missing.md", p.stderr)


if __name__ == "__main__":
    unittest.main()
