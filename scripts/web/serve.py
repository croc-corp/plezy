#!/usr/bin/env python3
"""Serve build/web for local use or testing.

    python3 scripts/web/serve.py [--port 8080] [--host 127.0.0.1] [--dir build/web]

Browsers only install PWAs and run service workers on HTTPS or on localhost,
so open http://localhost:<port>/ rather than a LAN address.
"""

from __future__ import annotations

import argparse
import functools
import http.server
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

TYPES = {
    ".wasm": "application/wasm",
    ".mjs": "text/javascript",
    ".js": "text/javascript",
    ".json": "application/json",
    ".webmanifest": "application/manifest+json",
    ".ttf": "font/ttf",
    ".otf": "font/otf",
    ".frag": "application/octet-stream",
}


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map, **TYPES}

    def end_headers(self) -> None:
        path = self.path.split("?", 1)[0]
        # The service worker and shell must revalidate so updates are seen;
        # everything else is versioned through the service worker's precache.
        if path.endswith(("/", ".html", "sw.js", "flutter_bootstrap.js", "manifest.json", "version.json")):
            self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def log_message(self, format: str, *args) -> None:  # noqa: A002 - stdlib signature
        if args and str(args[1]).startswith(("4", "5")):
            super().log_message(format, *args)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--dir", type=Path, default=ROOT / "build" / "web")
    args = parser.parse_args()
    if not (args.dir / "index.html").exists():
        raise SystemExit(f"{args.dir} has no index.html; run scripts/web/build.sh first")
    handler = functools.partial(Handler, directory=str(args.dir))
    with http.server.ThreadingHTTPServer((args.host, args.port), handler) as server:
        print(f"Serving {args.dir} at http://localhost:{args.port}/")
        server.serve_forever()


if __name__ == "__main__":
    main()
