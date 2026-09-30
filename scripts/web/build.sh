#!/usr/bin/env bash
# Build Plezy for the web as an installable PWA.
#
#   scripts/web/build.sh [--base-href /path/] [--profile] [--js-only] [-- <extra flutter build args>]
#
# Output: build/web, static files to serve over HTTPS or from localhost.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BASE_HREF="/"
MODE="--release"
TARGET=(--wasm)
EXTRA=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-href) BASE_HREF="$2"; shift 2 ;;
    --profile) MODE="--profile"; shift ;;
    --js-only) TARGET=(); shift ;;
    --) shift; EXTRA=("$@"); break ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

log "$("$FLUTTER_BIN" --version 2>/dev/null | head -1)"
check_codemod

log "Resolving packages"
"$FLUTTER_BIN" pub get --enforce-lockfile >/dev/null

GIT_COMMIT="$(git rev-parse HEAD 2>/dev/null || true)"
log "Building web app (${MODE#--}, ${TARGET[*]:-js only})"
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

log "Adding sqlite3.wasm $SQLITE3_VERSION, the drift worker and hls.js $HLS_JS_VERSION"
install_runtime_files "$OUT"

log "Generating service worker"
python3 scripts/web/gen_sw.py "$OUT"

log "Done: $OUT ($(du -sh "$OUT" | cut -f1))"
