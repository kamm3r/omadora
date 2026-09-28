#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

plugin="$ROOT/install/fedora/limine.install"
conf="$ROOT/install/fedora/kernel-install.conf"
shipped_migration="$ROOT/migrations/1790575242.sh"

test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

grep -qx 'layout=other' "$conf" && grep -qx 'BOOT_ROOT=/boot' "$conf" ||
  fail "kernel-install keeps Fedora's /boot layout"
pass "kernel-install keeps Fedora's /boot layout"

grep -q 'kernel-install.conf" /etc/kernel/install.conf$' "$ROOT/install/fedora/bootloader.sh" &&
  grep -q 'limine.install" /etc/kernel/install.d/96-limine.install$' "$ROOT/install/fedora/bootloader.sh" ||
  fail "the bootloader installer sets up kernel-install for Limine"
pass "the bootloader installer sets up kernel-install for Limine"

# The plugin's paths are fixed literals; retarget a scratch copy at a fake /boot
# and a stub limine-entry-tool that records its arguments.
grep -Fxq 'boot_dir=/boot' "$plugin" || fail "the plugin reads kernels from /boot"
grep -Fxq 'for candidate in /usr/local/bin/limine-entry-tool /usr/bin/limine-entry-tool; do' "$plugin" ||
  fail "the plugin calls limine-entry-tool by absolute path"
[[ -x $plugin ]] || fail "the plugin is executable"
pass "the plugin uses fixed paths and is executable"

boot="$test_dir/boot"
calls="$test_dir/calls"
mkdir -p "$boot"
cat >"$test_dir/limine-entry-tool" <<STUB
#!/bin/bash
printf '%s\n' "\$*" >>"$calls"
[[ ! -e "$test_dir/tool-fails" ]]
STUB
chmod +x "$test_dir/limine-entry-tool"

sed -e "s|^boot_dir=/boot$|boot_dir=$boot|" \
  -e "s|^for candidate in /usr/local/bin/limine-entry-tool /usr/bin/limine-entry-tool; do$|for candidate in $test_dir/limine-entry-tool; do|" \
  "$plugin" >"$test_dir/plugin"
sed -e "s|^for candidate in /usr/local/bin/limine-entry-tool /usr/bin/limine-entry-tool; do$|for candidate in $test_dir/absent; do|" \
  "$plugin" >"$test_dir/plugin-without-limine"

version=7.2.6-201.fc44.x86_64
: >"$calls"
if bash "$test_dir/plugin" add "$version" 2>/dev/null; then fail "a kernel without an initramfs is not registered"; fi
[[ ! -s $calls ]] || fail "a kernel without an initramfs is not registered" "$(<"$calls")"
pass "a kernel without an initramfs is reported, not registered"

touch "$boot/vmlinuz-$version" "$boot/initramfs-$version.img"
bash "$test_dir/plugin" add "$version" || fail "adding a kernel registers it"
[[ $(<"$calls") == "--add-kernel kernel-$version $boot/vmlinuz-$version $boot/initramfs-$version.img --quiet" ]] ||
  fail "adding a kernel registers it" "$(<"$calls")"
pass "adding a kernel registers it with its kernel image before its initramfs"

: >"$calls"
bash "$test_dir/plugin" remove "$version" || fail "removing a kernel drops its entry"
[[ $(<"$calls") == "--remove-kernel kernel-$version --quiet" ]] || fail "removing a kernel drops its entry" "$(<"$calls")"
touch "$test_dir/tool-fails"
bash "$test_dir/plugin" remove "$version" 2>/dev/null || fail "a failed entry removal does not fail the kernel removal"
rm "$test_dir/tool-fails"
pass "removing a kernel drops its entry, and a failed drop does not fail the removal"

: >"$calls"
bash "$test_dir/plugin-without-limine" add "$version" || fail "a machine without Limine is left alone"
[[ ! -s $calls ]] || fail "a machine without Limine is left alone"
pass "a machine without Limine is left alone"

# Migration: privileged paths are fixed literals too, so a scratch copy points
# them at a fake /etc while sudo runs the real commands.
for literal in 'limine_config=/etc/default/limine' 'machine_id_file=/etc/machine-id' \
  'kernel_install_conf=/etc/kernel/install.conf' 'limine_plugin=/etc/kernel/install.d/96-limine.install'; do
  grep -Fxq "$literal" "$shipped_migration" || fail "the migration keeps $literal fixed"
done
pass "the migration keeps its privileged paths fixed"

etc="$test_dir/etc"
esp="$test_dir/esp"
machine_id=0123456789abcdef0123456789abcdef
migration="$test_dir/migration.sh"
sed -e "s|^limine_config=/etc/default/limine$|limine_config=$etc/default/limine|" \
  -e "s|^machine_id_file=/etc/machine-id$|machine_id_file=$etc/machine-id|" \
  -e "s|^kernel_install_conf=/etc/kernel/install.conf$|kernel_install_conf=$etc/kernel/install.conf|" \
  -e "s|^limine_plugin=/etc/kernel/install.d/96-limine.install$|limine_plugin=$etc/kernel/install.d/96-limine.install|" \
  "$shipped_migration" >"$migration"

mkdir -p "$test_dir/bin"
cat >"$test_dir/bin/sudo" <<STUB
#!/bin/bash
printf 'sudo %s\n' "\$*" >>"$calls"
exec "\$@"
STUB
chmod +x "$test_dir/bin/sudo"

reset_machine() {
  rm -rf "$etc" "$esp"
  mkdir -p "$etc/default" "$esp/$machine_id/kernel-$version" "$esp/$machine_id/limine_history" \
    "$esp/$machine_id/0-rescue" "$esp/$machine_id/$version" "$esp/loader/entries"
  printf 'ESP_PATH="%s"\n' "$esp" >"$etc/default/limine"
  printf '%s\n' "$machine_id" >"$etc/machine-id"
  touch "$esp/$machine_id/kernel-$version/vmlinuz" "$esp/$machine_id/limine_history/snapshots.json" \
    "$esp/$machine_id/0-rescue/linux" "$esp/$machine_id/$version/linux" "$esp/$machine_id/$version/initrd" \
    "$esp/loader/entries/$machine_id-$version.conf" "$esp/loader/entries/$machine_id-0-rescue.conf" \
    "$esp/loader/entries/other-os.conf" "$esp/loader/random-seed"
  : >"$calls"
}

run_migration() {
  OMARCHY_PATH="$ROOT" PATH="$test_dir/bin:$PATH" bash -euo pipefail "$migration" >"$test_dir/output" 2>&1
}

reset_machine
run_migration || fail "the migration runs" "$(<"$test_dir/output")"
cmp -s "$conf" "$etc/kernel/install.conf" || fail "the migration installs the kernel-install layout"
cmp -s "$plugin" "$etc/kernel/install.d/96-limine.install" || fail "the migration installs the Limine plugin"
[[ $(stat -c %a "$etc/kernel/install.conf") == 644 && $(stat -c %a "$etc/kernel/install.d/96-limine.install") == 755 ]] ||
  fail "the migration installs the layout 0644 and the plugin 0755"
pass "the migration installs the layout and the Limine plugin"

[[ ! -e $esp/$machine_id/0-rescue && ! -e $esp/$machine_id/$version ]] ||
  fail "the migration clears the ESP entry directories kernel-install made"
[[ ! -e $esp/loader/entries/$machine_id-$version.conf && ! -e $esp/loader/entries/$machine_id-0-rescue.conf ]] ||
  fail "the migration clears the ESP loader entries kernel-install made"
[[ -f $esp/$machine_id/kernel-$version/vmlinuz && -f $esp/$machine_id/limine_history/snapshots.json ]] ||
  fail "the migration keeps Limine's kernel copies and snapshot history"
[[ -f $esp/loader/entries/other-os.conf && -f $esp/loader/random-seed ]] ||
  fail "the migration keeps loader files that are not this machine's kernel-install entries"
pass "the migration clears only what kernel-install left on the ESP"

: >"$calls"
run_migration || fail "the migration can run again" "$(<"$test_dir/output")"
pass "the migration can run again"

reset_machine
printf 'layout=bls\n' >"$test_dir/custom.conf"
mkdir -p "$etc/kernel"
cp "$test_dir/custom.conf" "$etc/kernel/install.conf"
run_migration || fail "a custom kernel-install layout does not stop the migration" "$(<"$test_dir/output")"
cmp -s "$test_dir/custom.conf" "$etc/kernel/install.conf" || fail "a custom kernel-install layout is left in place"
grep -q 'Leaving your' "$test_dir/output" || fail "a custom kernel-install layout is reported"
[[ -f $etc/kernel/install.d/96-limine.install ]] || fail "the plugin is installed beside a custom layout"
pass "a custom kernel-install layout is left in place and reported"

reset_machine
rm "$etc/default/limine"
run_migration || fail "a machine without Limine skips the migration" "$(<"$test_dir/output")"
[[ ! -s $calls && ! -e $etc/kernel ]] || fail "a machine without Limine is left alone" "$(<"$calls")"
[[ -d $esp/$machine_id/0-rescue ]] || fail "a machine without Limine keeps its ESP as it is"
pass "a machine without Limine is left alone"
