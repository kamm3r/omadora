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
