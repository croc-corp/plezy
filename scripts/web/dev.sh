#!/usr/bin/env bash
# Run Plezy's web build for development, with hot restart (press R).
#
#   scripts/web/dev.sh [--port 8080] [-- <extra flutter run args>]
#
# Serves a debug (dart2js/DDC) build at http://localhost:<port>/. Use
# scripts/web/build.sh for the dart2wasm release build.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PORT=8080
EXTRA=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) PORT="$2"; shift 2 ;;
    --) shift; EXTRA=("$@"); break ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

check_codemod
"$FLUTTER_BIN" pub get --enforce-lockfile >/dev/null

# flutter run serves web/ as-is; these files are gitignored there.
install_runtime_files "$ROOT/web"

exec "$FLUTTER_BIN" run -d web-server --web-port "$PORT" --web-hostname localhost ${EXTRA[@]+"${EXTRA[@]}"}
