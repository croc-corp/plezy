#!/usr/bin/env python3
"""Write build/web/sw.js from sw.template.js with a precache manifest.

Precaches what the dart2wasm build needs to start: the shell, the wasm app,
the skwasm renderer, the database runtime and the asset bundle. The dart2js
fallback (only used by browsers without WasmGC) is left to runtime caching.
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

TEMPLATE = Path(__file__).with_name("sw.template.js")

# Relative to the build root. Directories are included recursively. skwasm_heavy
# (for browsers without ImageDecoder, i.e. not Chrome) is left to runtime caching.
PRECACHE = [
    "index.html",
    "flutter_bootstrap.js",
    "manifest.json",
    "favicon.png",
    "icons",
    "main.dart.wasm",
    "main.dart.mjs",
    "canvaskit/skwasm.js",
    "canvaskit/skwasm.wasm",
    "sqlite3.wasm",
    "drift_worker.js",
    "vendor",
    "assets",
    "version.json",
]

# Loaded on demand, if ever: the license page.
EXCLUDE = {"assets/NOTICES"}


def main() -> int:
    out = Path(sys.argv[1])
    entries = []
    for rel in PRECACHE:
        path = out / rel
        files = sorted(p for p in path.rglob("*") if p.is_file()) if path.is_dir() else [path]
        for file in files:
            if file.relative_to(out).as_posix() in EXCLUDE:
                continue
            if not file.exists():
                print(f"warning: {file.relative_to(out)} missing from build, not precached", file=sys.stderr)
                continue
            digest = hashlib.sha256(file.read_bytes()).hexdigest()[:16]
            entries.append((file.relative_to(out).as_posix(), digest))

    build_id = hashlib.sha256(json.dumps(entries).encode()).hexdigest()[:16]
    source = TEMPLATE.read_text()
    source = source.replace("'__BUILD_ID__'", json.dumps(build_id))
    source = source.replace("__PRECACHE__", json.dumps(entries, indent=0))
    (out / "sw.js").write_text(source)
    size = sum((out / p).stat().st_size for p, _ in entries)
    print(f"sw.js: build {build_id}, {len(entries)} files, {size / 1e6:.1f} MB precached")
    return 0


if __name__ == "__main__":
    sys.exit(main())
