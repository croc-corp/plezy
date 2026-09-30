#!/usr/bin/env bash
# Build Plezy for the web as an installable PWA.
#
#   scripts/web/build.sh [--base-href /path/] [--debug] [--js-only] [-- <extra flutter build args>]
#
# Output: build/web (static files; serve them over HTTPS or from localhost).
#
# The Flutter SDK pinned by upstream CI (.github/workflows/ci.yml) is fetched
# into ~/.cache/plezy-web unless $FLUTTER points at a flutter binary.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE_HREF="/"
MODE="--release"
TARGET=(--wasm)
EXTRA=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-href) BASE_HREF="$2"; shift 2 ;;
    --debug) MODE="--profile"; shift ;;
    --js-only) TARGET=(); shift ;;
    --) shift; EXTRA=("$@"); break ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

# sqlite3.wasm must come from the same sqlite3.dart release as the locked
# `sqlite3` package; bump both together (see scripts/web/README.md).
SQLITE3_VERSION="3.5.0"
SQLITE3_WASM_SHA256="41cf968998241465d8b1dfffb1eb60dd10c35de5022a3647e14174ea3af84143"
HLS_JS_VERSION="1.7.3"
HLS_JS_SHA256="a12e7ee1cd64a69dcdb314157e45dafcba705bfb0b1440b7935cb265d374423e"

CACHE_DIR="${PLEZY_WEB_CACHE:-$HOME/.cache/plezy-web}"
mkdir -p "$CACHE_DIR"

log() { printf '\033[1m==> %s\033[0m\n' "$*"; }

sha256() { shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1 || sha256sum "$1" | cut -d' ' -f1; }

fetch_pinned() { # url sha256 dest
  local url="$1" sum="$2" dest="$3"
  if [[ ! -f "$dest" || "$(sha256 "$dest")" != "$sum" ]]; then
    curl -fsSL --retry 3 -o "$dest.tmp" "$url"
    local got; got="$(sha256 "$dest.tmp")"
    if [[ "$got" != "$sum" ]]; then
      rm -f "$dest.tmp"
      echo "checksum mismatch for $url: expected $sum, got $got" >&2
      exit 1
    fi
    mv "$dest.tmp" "$dest"
  fi
}

# --- Flutter SDK -------------------------------------------------------------
if [[ -n "${FLUTTER:-}" ]]; then
  FLUTTER_BIN="$FLUTTER"
else
  FLUTTER_VERSION="$(sed -n 's/^ *FLUTTER_VERSION: *"\([^"]*\)".*/\1/p' .github/workflows/ci.yml | head -1)"
  [[ -n "$FLUTTER_VERSION" ]] || { echo "could not read FLUTTER_VERSION from ci.yml" >&2; exit 1; }
  SDK="$CACHE_DIR/flutter-$FLUTTER_VERSION"
  if [[ ! -x "$SDK/bin/flutter" ]]; then
    log "Fetching Flutter $FLUTTER_VERSION"
    git clone --quiet --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$SDK"
  fi
  FLUTTER_BIN="$SDK/bin/flutter"
fi
DART_BIN="$(dirname "$FLUTTER_BIN")/dart"
"$FLUTTER_BIN" config --no-analytics >/dev/null 2>&1 || true
log "$("$FLUTTER_BIN" --version 2>/dev/null | head -1)"

# --- Sources -----------------------------------------------------------------
if ! python3 scripts/web/codemod.py --check >/dev/null; then
  python3 scripts/web/codemod.py --check || true
  echo "Upstream code reads dart:io's Platform directly. Run scripts/web/codemod.py and commit the result." >&2
  exit 1
fi

log "Resolving packages"
"$FLUTTER_BIN" pub get --enforce-lockfile

# --- App ---------------------------------------------------------------------
GIT_COMMIT="$(git rev-parse HEAD 2>/dev/null || true)"
log "Building web app ($MODE ${TARGET[*]:-js})"
"$FLUTTER_BIN" build web "$MODE" ${TARGET[@]+"${TARGET[@]}"} \
  --base-href "$BASE_HREF" \
  --no-web-resources-cdn \
  --dart-define=GIT_COMMIT="$GIT_COMMIT" \
  ${EXTRA[@]+"${EXTRA[@]}"}

OUT="$ROOT/build/web"
rm -f "$OUT/drift_worker.dart" "$OUT/flutter_service_worker.js"

# mpv's subtitle fonts and GLSL shaders have no consumer in the browser, and
# Flutter web downloads every FontManifest family at startup (16 MB for the
# Go Noto pair). Browser font fallback covers the glyphs they were for.
log "Pruning native-only assets"
rm -rf "$OUT/assets/assets/shaders" "$OUT/assets/assets/go-noto-"*.ttf
python3 - "$OUT/assets/FontManifest.json" <<'PY'
import json, sys
path = sys.argv[1]
fonts = [f for f in json.load(open(path)) if not f["family"].startswith("Go Noto")]
json.dump(fonts, open(path, "w"))
PY

# --- Database runtime (drift over sqlite3.wasm) ------------------------------
log "Adding sqlite3.wasm $SQLITE3_VERSION and the drift worker"
fetch_pinned "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-$SQLITE3_VERSION/sqlite3.wasm" \
  "$SQLITE3_WASM_SHA256" "$CACHE_DIR/sqlite3-$SQLITE3_VERSION.wasm"
cp "$CACHE_DIR/sqlite3-$SQLITE3_VERSION.wasm" "$OUT/sqlite3.wasm"
"$DART_BIN" compile js -O4 --no-source-maps -o "$OUT/drift_worker.js" web/drift_worker.dart >/dev/null
rm -f "$OUT/drift_worker.js.deps"

# --- Video: hls.js for transcoded streams ------------------------------------
log "Adding hls.js $HLS_JS_VERSION"
mkdir -p "$OUT/vendor"
fetch_pinned "https://cdn.jsdelivr.net/npm/hls.js@$HLS_JS_VERSION/dist/hls.min.js" \
  "$HLS_JS_SHA256" "$CACHE_DIR/hls-$HLS_JS_VERSION.min.js"
cp "$CACHE_DIR/hls-$HLS_JS_VERSION.min.js" "$OUT/vendor/hls.min.js"

# --- Service worker ----------------------------------------------------------
log "Generating service worker"
python3 scripts/web/gen_sw.py "$OUT"

log "Done: $OUT ($(du -sh "$OUT" | cut -f1))"
