"""Publish StrictDoc HTML into docs/ for GitHub Pages.

Expects StrictDoc export at .strictdoc_build/html/ (see Makefile).
Copies that tree into docs/ so Pages source /docs serves the site root.
"""
from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / ".strictdoc_build" / "html"
DOCS = ROOT / "docs"

# Keep these under docs/ if present (not StrictDoc site files).
KEEP_NAMES = {".nojekyll", "CNAME", "README.md"}


def main() -> None:
    if not SRC.is_dir():
        raise SystemExit(f"StrictDoc HTML not found at {SRC}")

    DOCS.mkdir(parents=True, exist_ok=True)

    for child in list(DOCS.iterdir()):
        if child.name in KEEP_NAMES:
            continue
        if child.is_dir():
            shutil.rmtree(child)
        else:
            child.unlink()

    for item in SRC.iterdir():
        dest = DOCS / item.name
        if item.is_dir():
            shutil.copytree(item, dest)
        else:
            shutil.copy2(item, dest)

    # Avoid Jekyll processing on GitHub Pages.
    (DOCS / ".nojekyll").write_text("", encoding="utf-8")

    print(f"Published StrictDoc HTML to {DOCS}")


if __name__ == "__main__":
    main()
