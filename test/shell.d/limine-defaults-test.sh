#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

packaged_defaults="$ROOT/etc/limine-entry-tool.d/omarchy-defaults.conf"

grep -Fq 'KERNEL_CMDLINE[default]+=" initramfs_async=0"' "$packaged_defaults" ||
  fail "the packaged Limine defaults still unpack the initramfs synchronously"
pass "packaged Limine defaults keep Plymouth alive at the LUKS prompt"

grep -Fxq 'KERNEL_CMDLINE[default]+=" systemd.tty.term.console=dumb"' "$packaged_defaults" ||
  fail "the packaged Limine defaults let PID 1 wait for the console to answer a size query"
pass "packaged Limine defaults keep PID 1 from waiting on the console"

grep -Fxq 'BOOT_ORDER="*, *fallback, Snapshots"' "$packaged_defaults" ||
  fail "packaged Limine defaults keep Fedora kernels and snapshots in boot order"
pass "packaged Limine defaults keep Fedora kernels and snapshots in boot order"

limine_template="$ROOT/default/limine/limine.conf"
grep -Fxq 'timeout: 1' "$limine_template" ||
  fail "the Limine template still waits out a long boot menu timeout"
pass "Limine template waits 1 second for a key at boot"
grep -Fxq 'quiet: yes' "$limine_template" ||
  fail "the Limine template still draws the boot menu on every boot"
pass "Limine template keeps the boot menu quiet until a key is pressed"

# Fedora often keeps the ESP at /boot/efi below a separate ext4 /boot.
# Direct Boot must register the actual ESP partition and its UKI.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/esp/EFI/Linux"
touch "$work/esp/EFI/Linux/omarchy_kernel.efi"
printf 'Test Firmware\n' >"$work/vendor"
cat >"$work/bin/omarchy-hw-aarch64-apple" <<'STUB'
#!/bin/bash
exit 1
STUB
cat >"$work/bin/sudo" <<'STUB'
#!/bin/bash
exec "$@"
STUB
cat >"$work/bin/efibootmgr" <<'STUB'
#!/bin/bash
if (( $# )); then printf '%s\n' "$*" >"$DIRECT_BOOT_CALL"; fi
STUB
cat >"$work/bin/bootctl" <<'STUB'
#!/bin/bash
echo "$DIRECT_BOOT_ESP"
STUB
cat >"$work/bin/findmnt" <<'STUB'
#!/bin/bash
[[ ${@: -1} == "$DIRECT_BOOT_ESP" ]] || exit 1
echo /dev/nvme0n1p1
STUB
printf '#!/bin/bash\nexit 0\n' >"$work/bin/gum"
printf '#!/bin/bash\necho test\n' >"$work/bin/omarchy-i18n"
chmod +x "$work/bin/"*
sed "s|/sys/class/dmi/id/bios_vendor|$work/vendor|" "$ROOT/bin/omarchy-setup-direct-boot" >"$work/direct"
DIRECT_BOOT_CALL="$work/call" DIRECT_BOOT_ESP="$work/esp" PATH="$work/bin:$ROOT/bin:$PATH" \
  bash "$work/direct" >"$work/output" 2>&1 || fail "Direct Boot supports a separately mounted ESP" "$(cat "$work/output")"
[[ $(cat "$work/call") == *'--disk /dev/nvme0n1 --part 1'* && $(cat "$work/call") == *'\EFI\Linux\omarchy_kernel.efi'* ]] ||
  fail "Direct Boot registers the ESP containing its UKI" "$(cat "$work/call")"
pass "Direct Boot resolves the actual ESP instead of assuming /boot"

# Exercise the installer seed block without package operations or root paths.
python3 - "$ROOT" "$work" <<'PY'
from pathlib import Path
import sys
root, work = map(Path, sys.argv[1:])
s = (root / 'install/fedora/bootloader.sh').read_text()
s = s[s.index('# 1.'):s.index('# 2.')]
s = s.replace(' /etc/default/limine', ' ' + str(work / 'etc/default/limine'))
s = s.replace(' /etc/limine-entry-tool.d', ' ' + str(work / 'etc/limine-entry-tool.d'))
(work / 'seed').write_text(s)
PY
mkdir -p "$work/etc/default"
rm "$work/esp/limine.conf" 2>/dev/null || true
OMADORA_ROOT="$ROOT" DIRECT_BOOT_ESP="$work/esp" PATH="$work/bin:$PATH" \
  bash -e "$work/seed" || fail "the installer seeds the actual ESP"
cmp -s "$ROOT/default/limine/limine.conf" "$work/esp/limine.conf" || fail "the installed ESP receives Omarchy's menu template"
[[ $(cat "$work/etc/default/limine") == "ESP_PATH=\"$work/esp\"" ]] || fail "the image builder receives the actual ESP path"
pass "fresh installation seeds the menu and image-builder path on the actual ESP"
