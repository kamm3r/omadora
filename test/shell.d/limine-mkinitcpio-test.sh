#!/bin/bash

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/modules/first" "$work/modules/second" "$work/modules/orphan" "$work/boot" "$work/tools"
touch "$work/modules/first/vmlinuz" "$work/modules/second/vmlinuz"
export LIMINE_TEST_CALLS="$work/calls"
cat >"$work/tools/dracut" <<'STUB'
#!/bin/bash
printf 'dracut %s\n' "$*" >>"$LIMINE_TEST_CALLS"
printf 'initramfs\n' >"$2"
STUB
cat >"$work/tools/limine-entry-tool" <<'STUB'
#!/bin/bash
printf 'entry %s\n' "$*" >>"$LIMINE_TEST_CALLS"
[[ -f $3 && -f $4 ]]
STUB
chmod +x "$work/tools/"*

# Redirect fixed system paths in a private copy; no host boot files are touched.
python3 - "$ROOT" "$work" <<'PY'
from pathlib import Path
import sys
root, work = map(Path, sys.argv[1:])
source = (root / "install/fedora/limine-mkinitcpio").read_text()
source = source.replace("/usr/lib/modules/", str(work / "modules") + "/")
source = source.replace("/boot/", str(work / "boot") + "/")
source = source.replace("dracut -f", str(work / "tools/dracut") + " -f")
source = source.replace("/usr/local/bin/limine-entry-tool", str(work / "tools/limine-entry-tool"))
(work / "helper").write_text(source)
PY

# A privileged PATH lacks /usr/local/bin and cannot find the entry tool by name.
PATH=/usr/bin:/bin bash "$work/helper" >/dev/null || fail "Limine rebuild works with a restricted privileged PATH"
grep -Fxq "entry --add-kernel kernel-first $work/modules/first/vmlinuz $work/boot/initramfs-first.img --quiet" "$work/calls" || fail "first kernel is registered with its rebuilt initramfs"
grep -Fxq "entry --add-kernel kernel-second $work/modules/second/vmlinuz $work/boot/initramfs-second.img --quiet" "$work/calls" || fail "second kernel is registered with its rebuilt initramfs"
[[ $(wc -l <"$work/calls") == 4 ]] || fail "orphan module directories are skipped"
pass "Limine rebuild registers every kernel and skips orphans with a restricted privileged PATH"
