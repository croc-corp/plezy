#!/usr/bin/env python3
"""Rewrite upstream Dart sources so the web build can use them.

`dart:io`'s `Platform` throws on the web, so every library that reads it
imports `lib/utils/io_platform.dart` instead, which re-exports the real
`Platform` on native hosts and a browser stand-in on the web.

Idempotent: re-run after merging upstream (`scripts/web/build.sh` checks this
with `--check`) and commit the result.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / "lib"
SHIM = LIB / "utils" / "io_platform.dart"
SHIM_FILES = {SHIM, LIB / "utils" / "io_platform_native.dart", LIB / "utils" / "io_platform_web.dart"}

IO_IMPORT = re.compile(r"^import 'dart:io'(?P<combinator>\s+(?:show|hide)\s+[^;]+)?;[ \t]*\n", re.MULTILINE)
PLATFORM_USE = re.compile(r"(?<![\w$])Platform\s*\.")
IMPORT_LINE = re.compile(r"^import\s+'[^']+'[^;]*;[ \t]*$", re.MULTILINE)
PART = re.compile(r"^part\s+'([^']+)';", re.MULTILINE)


def _names(combinator: str) -> list[str]:
    return [n.strip() for n in combinator.split(None, 1)[1].split(",") if n.strip()]


def _rewrite_io_import(match: re.Match[str]) -> str:
    combinator = (match.group("combinator") or "").strip()
    if not combinator:
        return "import 'dart:io' hide Platform;\n"
    keyword = combinator.split(None, 1)[0]
    names = _names(combinator)
    if keyword == "show":
        rest = [n for n in names if n != "Platform"]
        return f"import 'dart:io' show {', '.join(rest)};\n" if rest else ""
    if "Platform" not in names:
        names.append("Platform")
    return f"import 'dart:io' hide {', '.join(names)};\n"


def rewrite(path: Path, source: str) -> str:
    if path in SHIM_FILES or path.name.endswith((".g.dart", ".freezed.dart")):
        return source
    if source.lstrip().startswith("part of"):
        return source  # Parts share their library's imports.
    library = source + "".join((path.parent / part).read_text() for part in PART.findall(source))
    if not PLATFORM_USE.search(library) or not IO_IMPORT.search(source):
        return source

    shim = os.path.relpath(SHIM, path.parent).replace(os.sep, "/")
    shim_import = f"import '{shim}';"

    out = IO_IMPORT.sub(_rewrite_io_import, source)
    if shim_import not in out:
        imports = list(IMPORT_LINE.finditer(out))
        at = imports[-1].end() if imports else 0
        out = f"{out[:at]}\n{shim_import}{out[at:]}"
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="list files that need rewriting and exit 1 if any")
    args = parser.parse_args()

    pending = []
    for path in sorted(LIB.rglob("*.dart")):
        source = path.read_text()
        result = rewrite(path, source)
        if result == source:
            continue
        pending.append(path.relative_to(ROOT))
        if not args.check:
            path.write_text(result)

    for p in pending:
        print(("needs rewrite: " if args.check else "rewrote: ") + str(p))
    # Dropping an import can leave a stray blank line; let the formatter settle it.
    if pending and not args.check and shutil.which("dart"):
        subprocess.run(["dart", "format", *map(str, pending)], cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
    return 1 if args.check and pending else 0


if __name__ == "__main__":
    sys.exit(main())
