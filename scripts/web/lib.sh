# Shared by scripts/web/build.sh and scripts/web/dev.sh; source, don't run.
# Sets ROOT, FLUTTER_BIN, DART_BIN and CACHE_DIR, and defines helpers.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# sqlite3.wasm must come from the same sqlite3.dart release as the locked
# `sqlite3` package; bump both together (see scripts/web/README.md).
SQLITE3_VERSION="3.5.0"
SQLITE3_WASM_SHA256="41cf968998241465d8b1dfffb1eb60dd10c35de5022a3647e14174ea3af84143"
HLS_JS_VERSION="1.7.3"
HLS_JS_SHA256="a12e7ee1cd64a69dcdb314157e45dafcba705bfb0b1440b7935cb265d374423e"

CACHE_DIR="${PLEZY_WEB_CACHE:-$HOME/.cache/plezy-web}"
mkdir -p "$CACHE_DIR"

log() { printf '\033[1m==> %s\033[0m\n' "$*"; }

sha256() {
  if command -v shasum >/dev/null; then shasum -a 256 "$1" | cut -d' ' -f1; else sha256sum "$1" | cut -d' ' -f1; fi
}

fetch_pinned() { # url sha256 dest
  local url="$1" sum="$2" dest="$3"
  if [[ -f "$dest" && "$(sha256 "$dest")" == "$sum" ]]; then return; fi
  curl -fsSL --retry 3 -o "$dest.tmp" "$url"
  local got
  got="$(sha256 "$dest.tmp")"
  if [[ "$got" != "$sum" ]]; then
    rm -f "$dest.tmp"
    echo "checksum mismatch for $url: expected $sum, got $got" >&2
    exit 1
  fi
  mv "$dest.tmp" "$dest"
}

# The Flutter SDK upstream CI pins, unless $FLUTTER names a flutter binary.
if [[ -n "${FLUTTER:-}" ]]; then
  FLUTTER_BIN="$FLUTTER"
else
  FLUTTER_VERSION="$(sed -n 's/^ *FLUTTER_VERSION: *"\([^"]*\)".*/\1/p' .github/workflows/ci.yml | head -1)"
  if [[ -z "$FLUTTER_VERSION" ]]; then
    echo "could not read FLUTTER_VERSION from .github/workflows/ci.yml" >&2
    exit 1
  fi
  SDK="$CACHE_DIR/flutter-$FLUTTER_VERSION"
  if [[ ! -x "$SDK/bin/flutter" ]]; then
    log "Fetching Flutter $FLUTTER_VERSION"
    git clone --quiet --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$SDK"
  fi
  FLUTTER_BIN="$SDK/bin/flutter"
fi
DART_BIN="$(dirname "$FLUTTER_BIN")/dart"
"$FLUTTER_BIN" config --no-analytics >/dev/null 2>&1 || true

check_codemod() {
  if ! python3 scripts/web/codemod.py --check >/dev/null; then
    python3 scripts/web/codemod.py --check || true
    echo "Upstream code reads dart:io's Platform directly. Run scripts/web/codemod.py and commit the result." >&2
    exit 1
  fi
}

# Copies the runtime files the app loads next to index.html into $1:
# sqlite3.wasm, drift_worker.js and vendor/hls.min.js.
install_runtime_files() {
  local out="$1"
  fetch_pinned "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-$SQLITE3_VERSION/sqlite3.wasm" \
    "$SQLITE3_WASM_SHA256" "$CACHE_DIR/sqlite3-$SQLITE3_VERSION.wasm"
  cp "$CACHE_DIR/sqlite3-$SQLITE3_VERSION.wasm" "$out/sqlite3.wasm"

  "$DART_BIN" compile js -O4 --no-source-maps -o "$out/drift_worker.js" web/drift_worker.dart >/dev/null
  rm -f "$out/drift_worker.js.deps"

  mkdir -p "$out/vendor"
  fetch_pinned "https://cdn.jsdelivr.net/npm/hls.js@$HLS_JS_VERSION/dist/hls.min.js" \
    "$HLS_JS_SHA256" "$CACHE_DIR/hls-$HLS_JS_VERSION.min.js"
  cp "$CACHE_DIR/hls-$HLS_JS_VERSION.min.js" "$out/vendor/hls.min.js"
}
