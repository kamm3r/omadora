#!/bin/bash

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/modules/first" "$work/modules/second" "$work/modules/orphan" "$work/boot" "$work/tools"
touch "$work/modules/first/vmlinuz" "$work/modules/second/vmlinuz"
export LIMINE_TEST_CALLS="$work/calls"
cat >"$work/common" <<'STUB'
initialize_header() { :; }
mutex_lock() { :; }
mutex_unlock() { :; }
run_boot_hooks() { :; }
is_uefi() { return 0; }
is_sb_installed() { return 1; }
sb_sign() { :; }
STUB
cat >"$work/tools/dracut" <<'STUB'
#!/bin/bash
printf 'dracut %s\n' "$*" >>"$LIMINE_TEST_CALLS"
[[ ${FAIL_BUILD:-0} != 1 ]] || exit 9
printf 'image\n' >"${@: -1}"
STUB
cat >"$work/tools/limine-entry-tool" <<'STUB'
#!/bin/bash
printf 'entry %s\n' "$*" >>"$LIMINE_TEST_CALLS"
if [[ $1 == --get-cmdline ]]; then echo 'root=UUID=test ro'; fi
if [[ $1 == --add-uki ]]; then [[ -s $3 ]]; fi
STUB
chmod +x "$work/tools/"*

# Retarget a scratch copy; no host boot files or locks are touched.
python3 - "$ROOT" "$work" <<'PY'
from pathlib import Path
import sys
root, work = map(Path, sys.argv[1:])
source = (root / "install/fedora/limine-mkinitcpio").read_text()
source = source.replace("/usr/lib/modules/", str(work / "modules") + "/")
source = source.replace("/etc/limine-entry-tool.d", str(work / "config"))
source = source.replace("/boot/", str(work / "boot") + "/")
source = source.replace("/usr/lib/limine/limine-common-functions", str(work / "common"))
source = source.replace('dracut "${options[@]}"', str(work / "tools/dracut") + ' "${options[@]}"')
source = source.replace("/usr/bin/limine-entry-tool", str(work / "tools/limine-entry-tool"))
(work / "helper").write_text(source)
PY

ENABLE_UKI=no PATH=/usr/bin:/bin bash "$work/helper" || fail "split-image rebuilding succeeds"
grep -Fq "entry --add-kernel kernel-first $work/modules/first/vmlinuz $work/boot/initramfs-first.img" "$work/calls" || fail "first kernel is registered"
grep -Fq "entry --add-kernel kernel-second $work/modules/second/vmlinuz $work/boot/initramfs-second.img" "$work/calls" || fail "second kernel is registered"
if grep -q orphan "$work/calls"; then fail "orphan module directories must be skipped"; fi
pass "split-image mode registers rebuilt kernels and skips orphan module directories"

: >"$work/calls"
ENABLE_UKI=yes PATH=/usr/bin:/bin bash "$work/helper" first || fail "UKI rebuilding succeeds"
grep -Fq -- '--uefi --kernel-image' "$work/calls" || fail "UEFI images must be generated"
grep -Fq -- '--kernel-cmdline root=UUID=test ro' "$work/calls" || fail "Direct Boot needs the resolved kernel command line"
add=$(grep -n 'entry --add-uki' "$work/calls" | cut -d: -f1)
remove=$(grep -n 'entry --remove-kernel' "$work/calls" | cut -d: -f1)
(( add < remove )) || fail "the old boot files must survive until UKI registration succeeds"
if grep -q second "$work/calls"; then fail "a per-kernel rebuild must leave other kernels alone"; fi
pass "UKI mode embeds the resolved command line and registers before retiring split files"

: >"$work/calls"
if ENABLE_UKI=yes FAIL_BUILD=1 bash "$work/helper" first; then fail "a failed UKI build must fail the rebuild"; fi
if grep -Eq 'entry --(add|remove)' "$work/calls"; then fail "a failed build must preserve the existing boot entry"; fi
pass "failed UKI builds preserve existing boot files and entries"

mkdir -p "$work/modules/6.9" "$work/modules/6.10"
touch "$work/modules/6.9/vmlinuz" "$work/modules/6.10/vmlinuz"
# The build failure keeps this focused on selection without publishing images.
ENABLE_UKI=yes FAIL_BUILD=1 bash "$work/helper" first || true
# Use numeric kernel fixtures alone so the version comparison is meaningful.
rm -rf "$work/modules/first" "$work/modules/second"
ENABLE_UKI=yes FAIL_BUILD=1 bash "$work/helper" 6.10 || true
grep -Fq 'BOOT_ORDER="kernel-6.10,' "$work/config/zz-fedora-kernel.conf" || fail "the newest kernel must be selected by version, not alphabetically"
pass "Fedora kernel selection prefers 6.10 over 6.9"
