"""Put repo root and src/ on sys.path so notebooks and scripts import ironair."""

from __future__ import annotations

import sys
from pathlib import Path


def setup_path() -> Path:
    """Return the repository root after inserting import paths."""
    here = Path(__file__).resolve().parent
    root = here.parent
    src = root / "src"
    for path in (root, src):
        text = str(path)
        if text not in sys.path:
            sys.path.insert(0, text)
    return root
