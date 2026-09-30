#!/usr/bin/env bash
# Package the already-built site for an ARM Chromebook's Linux environment.
# The browser bundle is architecture-independent; Flutter need not run there.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
[[ -f build/web/index.html ]] || { echo 'Run scripts/web/build.sh first' >&2; exit 1; }

python3 - <<'PY'
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

root = Path.cwd()
output = root / 'build' / 'plezy-web.zip'
with ZipFile(output, 'w', compression=ZIP_DEFLATED, compresslevel=9) as archive:
    for source in sorted((root / 'build' / 'web').rglob('*')):
        if source.is_file() and source.name != '.last_build_id':
            archive.write(source, 'plezy-web/' + source.relative_to(root / 'build' / 'web').as_posix())
    archive.write(root / 'scripts' / 'web' / 'serve.py', 'plezy-web/serve.py')
    archive.write(root / 'scripts' / 'web' / 'README.md', 'plezy-web/README.md')
    archive.writestr('plezy-web/run.sh', '#!/bin/sh\ncd "$(dirname "$0")"\nexec python3 serve.py --dir . --port "${1:-8080}"\n')
print(f'{output} ({output.stat().st_size // 1024 // 1024} MiB)')
PY
