#!/bin/bash

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
export OMARCHY_PATH="$ROOT" MIGRATION_CALLS="$work/calls"
python3 - "$ROOT" "$work" <<'PY'
from pathlib import Path
import sys
root, work = map(Path, sys.argv[1:])
source = (root / "migrations/1791892610.sh").read_text()
(work / "migration").write_text(source.replace("/usr/local/bin/limine-mkinitcpio", str(work / "helper")))
PY
cat >"$work/bin/sudo" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >>"$MIGRATION_CALLS"
[[ ${MIGRATION_INSTALL_FAIL:-0} == 0 ]] || exit 23
exec "$@"
STUB
chmod +x "$work/bin/sudo"
export PATH="$work/bin:$PATH"

bash -euo pipefail "$work/migration" >/dev/null
[[ ! -e $work/helper && ! -e $MIGRATION_CALLS ]] || fail "a machine without the shim is left alone"
printf 'old helper\n' >"$work/helper"
if MIGRATION_INSTALL_FAIL=1 bash -euo pipefail "$work/migration" >/dev/null; then
  fail "a failed helper install leaves the migration pending"
fi
[[ $(<"$work/helper") == "old helper" ]] || fail "a failed install preserves the old helper"
: >"$MIGRATION_CALLS"
bash -euo pipefail "$work/migration" >/dev/null
cmp -s "$work/helper" "$ROOT/install/fedora/limine-mkinitcpio" || fail "an existing helper is refreshed from the Fedora source"
[[ $(stat -c '%a' "$work/helper") == "755" ]] || fail "the refreshed helper is executable"
bash -euo pipefail "$work/migration" >/dev/null
[[ $(wc -l <"$MIGRATION_CALLS") == 1 ]] || fail "the helper refresh is idempotent"
pass "Limine shim migration preserves absent installs, reports failures, and refreshes existing installs once"
