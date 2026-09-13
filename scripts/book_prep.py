#!/usr/bin/env python3
"""book_prep — copy course/NN-*.md into a build dir with stable chapter ids and in-book links.

    python3 scripts/book_prep.py course build/book

- the first `# ` heading of NN-slug.md becomes `# Title {#ch-slug}`
- `](NN-slug.md)`   -> `](#ch-slug)`      (link to the chapter)
- `](NN-slug.md#a)` -> `](#a)`            (pandoc's auto id of that heading; duplicated
                                          section titles across lessons get -1/-2 suffixes,
                                          so such a link may land on the first twin)
Exit 1 on a link to a lesson file that does not exist.
"""
import pathlib
import re
import sys

LINK = re.compile(r"\]\((?:\./)?(\d{2}-[a-z0-9-]+)\.md(#[A-Za-z0-9_-]+)?\)")


def slug(stem: str) -> str:
    return stem[3:]  # drop "NN-"


def prep(course: pathlib.Path, out: pathlib.Path) -> int:
    chapters = sorted(p for p in course.glob("[0-9][0-9]-*.md"))
    known = {p.stem for p in chapters}
    out.mkdir(parents=True, exist_ok=True)
    bad = []
    for path in chapters:
        text = path.read_text(encoding="utf-8")

        def fix(m: re.Match) -> str:
            target, anchor = m.group(1), m.group(2)
            if target not in known:
                bad.append(f"{path.name}: link to {target}.md, which is not a lesson")
                return m.group(0)
            return f"](#{anchor[1:]})" if anchor else f"](#ch-{slug(target)})"

        text = LINK.sub(fix, text)
        text = re.sub(r"^# (.+?)\s*$", rf"# \1 {{#ch-{slug(path.stem)}}}", text, count=1, flags=re.M)
        (out / path.name).write_text(text, encoding="utf-8")
    for b in bad:
        print(f"book_prep: {b}", file=sys.stderr)
    return 1 if bad else 0


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    sys.exit(prep(pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])))
