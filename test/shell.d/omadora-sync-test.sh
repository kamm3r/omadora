#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

sync_root="$ROOT/default/omadora-sync"

# Everything below drives omadora-sync with stand-ins: no repository is
# queried, no package changes, and nothing runs as root.
if ! /usr/bin/python3 -I -c 'import libdnf5' 2>/dev/null; then
  skip "python3-libdnf5 is not installed; skipping omadora-sync engine checks"
else
  /usr/bin/python3 -I -B - "$sync_root" <<'PY' || fail "omadora-sync package groups are a valid inventory"
import collections, sys
sys.path.insert(0, sys.argv[1])
from omadora_sync.grouped_updates import GROUP_ORDER, default_package_groups_path, load_package_groups, partition_pending_updates

groups = load_package_groups(default_package_groups_path())
assert set(groups) == set(GROUP_ORDER), groups.keys()
counts = collections.Counter(name for names in groups.values() for name in names)
assert not [name for name, count in counts.items() if count > 1], counts
for key, name in (("kernel", "kernel-core"), ("graphic stack", "mesa-dri-drivers"), ("graphic stack", "akmod-nvidia"),
                  ("system core packages", "limine"), ("system core packages", "python3-libdnf5"),
                  ("desktop environment", "hyprland"), ("desktop environment", "quickshell")):
    assert name in groups[key], (key, name)
parts = {group.key: group.packages for group in partition_pending_updates(["kernel-core", "hyprland", "firefox"], groups)}
assert parts["kernel"] == ("kernel-core",) and parts["desktop environment"] == ("hyprland",), parts
assert parts["non-essential packages"] == ("firefox",), parts
PY
  pass "omadora-sync package groups are a valid inventory"

  /usr/bin/python3 -I -B - "$sync_root" <<'PY' || fail "boot images go through limine-mkinitcpio, with dracut as the fallback"
import logging, subprocess, sys
sys.path.insert(0, sys.argv[1])
from omadora_sync.grouped_updates import PackageGroup, validate_kernel_modules

log = logging.getLogger("test")
kernel = PackageGroup("kernel", "Kernel", ("kernel-core",))

def run(found, *, fail=None, dracut_enabled=True, group=kernel, packages=("kernel-core",)):
    calls = []
    def runner(command, **_):
        calls.append(command)
        return subprocess.CompletedProcess(command, 1 if command[0] == fail else 0, "", "")
    outcome = validate_kernel_modules(group, packages, log, dracut_enabled=dracut_enabled,
                                      command_finder=lambda name: f"/usr/bin/{name}" if name in found else None,
                                      command_runner=runner)
    return outcome, calls

outcome, calls = run({"akmods", "limine-mkinitcpio", "dracut"})
assert outcome.success and calls == [["akmods", "--force"], ["limine-mkinitcpio"]], calls
outcome, calls = run({"dracut"})
assert outcome.success and calls == [["dracut", "-f", "--regenerate-all"]], calls
outcome, calls = run(set())
assert not outcome.success and calls == [], calls
outcome, calls = run({"limine-mkinitcpio"}, fail="limine-mkinitcpio")
assert not outcome.success and "limine-mkinitcpio" in outcome.error, outcome
outcome, calls = run({"limine-mkinitcpio"}, dracut_enabled=False)
assert outcome.success and calls == [], calls
# Only the framework a non-kernel group touched is rebuilt.
graphics = PackageGroup("graphic stack", "Graphic stack", ("akmod-nvidia",))
outcome, calls = run({"akmods", "dkms", "limine-mkinitcpio"}, group=graphics, packages=("akmod-nvidia",))
assert calls == [["akmods", "--force"], ["limine-mkinitcpio"]], calls
PY
  pass "boot images go through limine-mkinitcpio, with dracut as the fallback"

  /usr/bin/python3 -I -B - "$sync_root" <<'PY' || fail "a group that fails validation is rolled back and revalidated"
import logging, sys
sys.path.insert(0, sys.argv[1])
from omadora_sync.dnf import DnfTransactionOutcome
from omadora_sync.grouped_updates import ValidationOutcome, load_package_groups, default_package_groups_path, run_grouped_updates

groups = load_package_groups(default_package_groups_path())
events = []
def transaction(packages, group):
    events.append(("update", group.key))
    return DnfTransactionOutcome(True, transaction_id=41, packages=tuple(packages), changed=True)
def rollback(transaction_id, group):
    events.append(("rollback", group.key, transaction_id))
    return DnfTransactionOutcome(True, changed=True)
def validator(group, packages, after_rollback):
    events.append(("validate", group.key, after_rollback))
    return ValidationOutcome(after_rollback, None if after_rollback else "limine-mkinitcpio failed")

summary = run_grouped_updates(["kernel-core", "firefox"], groups, transaction, rollback, validator, logging.getLogger("test"))
assert not summary.success
assert events[:4] == [("update", "kernel"), ("validate", "kernel", False), ("rollback", "kernel", 41), ("validate", "kernel", True)], events
assert ("update", "non-essential packages") in events, events
assert not summary.kernel_or_module_update_applied
PY
  pass "a group that fails validation is rolled back and revalidated"

  # The entrypoint has no .py suffix, so load it by path with the helpers it
  # would call replaced by recorders.
  cat >"$test_tmp/cli.py" <<'PY'
import importlib.machinery, importlib.util, io, logging, os, sys
entry = sys.argv[1]
loader = importlib.machinery.SourceFileLoader("omadora_sync_cli", entry)
spec = importlib.util.spec_from_loader(loader.name, loader)
cli = importlib.util.module_from_spec(spec)
loader.exec_module(cli)
PY

  /usr/bin/python3 -I -B - "$ROOT/bin/omadora-sync" <<PY || fail "listing updates runs as the caller; changing packages elevates"
$(cat "$test_tmp/cli.py")
elevated = []
cli.ensure_root = lambda: elevated.append(True)
cli.updatechecker = lambda: ["kernel-core"]
cli.install_system_updates = lambda: True
cli.check_repos = lambda: True
for command, expected in (("check-updates", []), ("check-repos", []), ("cli", [True]), ("repair", [True])):
    elevated.clear()
    sys.argv = ["omadora-sync", command]
    if command == "repair":
        cli.repair = lambda: True
    assert cli.main() == 0, command
    assert elevated == expected, (command, elevated)
PY
  pass "listing updates runs as the caller; changing packages elevates"

  mkdir -p "$test_tmp/bin"
  cat >"$test_tmp/bin/sudo" <<'STUB'
#!/bin/bash
printf '%s\n' "$@" >"$SUDO_LOG"
STUB
  chmod +x "$test_tmp/bin/sudo"
  (( EUID != 0 )) || fail "run the omadora-sync test as a regular user"
  SUDO_LOG="$test_tmp/sudo.log" PATH="$test_tmp/bin:$PATH" "$ROOT/bin/omadora-sync" cli
  mapfile -t sudo_args <"$test_tmp/sudo.log"
  [[ ${sudo_args[1]} == "-I" && ${sudo_args[2]} == "$ROOT/bin/omadora-sync" && ${sudo_args[3]} == "cli" ]] ||
    fail "omadora-sync elevates itself through sudo on PATH" "${sudo_args[*]}"
  [[ ! -e $sync_root/omadora_sync/__pycache__ ]] || fail "omadora-sync wrote bytecode into the checkout"
  pass "omadora-sync elevates through sudo on PATH, isolated and without bytecode"

  cat >"$test_tmp/bin/runuser" <<'STUB'
#!/bin/bash
printf '%s\n' "$@" >"$RUNUSER_LOG"
STUB
  chmod +x "$test_tmp/bin/runuser"
  RUNUSER_LOG="$test_tmp/runuser.log" SUDO_UID="$EUID" PATH="$test_tmp/bin:$PATH" \
    /usr/bin/python3 -I -B - "$ROOT/bin/omadora-sync" <<PY || fail "a kernel or driver update hands the reboot to omarchy-update-restart"
$(cat "$test_tmp/cli.py")
import pwd
cli.mark_reboot_required()
args = open(os.environ["RUNUSER_LOG"]).read().split("\n")[:-1]
assert args == ["-u", pwd.getpwuid(os.geteuid()).pw_name, "--", os.path.join(os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[1]))), "bin", "omarchy-state"), "set", "reboot-required"], args
os.remove(os.environ["RUNUSER_LOG"])
os.environ.pop("SUDO_UID")
cli.mark_reboot_required()
assert not os.path.exists(os.environ["RUNUSER_LOG"])
PY
  pass "a kernel or driver update hands the reboot to omarchy-update-restart"

  /usr/bin/python3 -I -B - "$ROOT/bin/omadora-sync" >"$test_tmp/stdout" 2>"$test_tmp/stderr" <<PY || fail "progress goes to stdout and problems to stderr"
$(cat "$test_tmp/cli.py")
cli.initialize_logging()
cli.logger.info("%s Kernel - progress", cli.SUCCESS_MARKER)
cli.logger.warning("Problem: cannot install both a and b")
cli.logger.error("%s Desktop environment - failed", cli.FAILURE_MARKER)
PY
  [[ $(<"$test_tmp/stdout") == "[OK] Kernel - progress" ]] || fail "progress goes to stdout and problems to stderr" "$(<"$test_tmp/stdout")"
  [[ $(<"$test_tmp/stderr") == $'Problem: cannot install both a and b\n[X] Desktop environment - failed' ]] ||
    fail "progress goes to stdout and problems to stderr" "$(<"$test_tmp/stderr")"
  pass "progress goes to stdout and problems to stderr, uncolored off a terminal"
fi

# Nobara appears only in the attribution, never as a code path.
if grep -rn -i 'nobara' "$ROOT/bin/omadora-sync" "$sync_root/omadora_sync" "$sync_root/package-groups.txt" |
  grep -v -e 'Derived from nobara-updater' -e 'nobara-project/nobara-core-packages' -e 'Nobara Project' -e "(Omadora's nobara-sync)" -e 'nobara-sync, no /lib/modules' -e 'derived from nobara-updater'; then
  fail "omadora-sync carries no Nobara code paths"
fi
[[ -f $sync_root/LICENSE ]] && grep -q 'GNU GENERAL PUBLIC LICENSE' "$sync_root/LICENSE" || fail "omadora-sync ships its GPL license"
pass "omadora-sync keeps Nobara to its attribution and ships the GPL"

# The update step: omadora-sync when its bindings are installed, plain dnf
# before the migration adds them, and Nobara's fixups first on Nobara.
stub_bin="$test_tmp/update-bin"
mkdir -p "$stub_bin"
cat >"$stub_bin/sudo" <<'STUB'
#!/bin/bash
exec "$@"
STUB
cat >"$stub_bin/systemd-run" <<'STUB'
#!/bin/bash
while [[ $1 == -* ]]; do shift; done
exec "$@"
STUB
cat >"$stub_bin/recorder" <<'STUB'
#!/bin/bash
printf '%s %s SUDO_USER=%s\n' "${0##*/}" "$*" "${SUDO_USER:-}" >>"$UPDATE_CALLS"
[[ ${0##*/} != "${FAIL_STEP:-}" ]]
STUB
for name in dnf nobara-sync; do ln -s recorder "$stub_bin/$name"; done
# The update runs $OMARCHY_PATH/bin/omadora-sync, so it gets its own fake root.
fake_root="$test_tmp/omarchy"
mkdir -p "$fake_root/bin"
ln -s "$stub_bin/recorder" "$fake_root/bin/omadora-sync"
cat >"$stub_bin/omarchy-pkg-present" <<'STUB'
#!/bin/bash
[[ $1 == python3-libdnf5 && ${LIBDNF5_PRESENT:-1} == 1 ]]
STUB
cat >"$stub_bin/omarchy-cmd-present" <<'STUB'
#!/bin/bash
[[ $1 == nobara-sync ]] && { [[ ${NOBARA:-0} == 1 ]]; exit; }
command -v "$1" >/dev/null
STUB
chmod +x "$stub_bin"/*

run_system_update() {
  : >"$test_tmp/calls"
  env -u SUDO_USER UPDATE_CALLS="$test_tmp/calls" OMARCHY_PATH="$fake_root" PATH="$stub_bin:$ROOT/bin:$PATH" \
    bash "$ROOT/bin/omarchy-update-system-pkgs" >"$test_tmp/update.out" 2>&1
}

run_system_update || fail "the system update runs omadora-sync" "$(<"$test_tmp/update.out")"
[[ $(<"$test_tmp/calls") == "omadora-sync cli SUDO_USER=" ]] || fail "the system update runs omadora-sync" "$(<"$test_tmp/calls")"
pass "the system update runs omadora-sync from OMARCHY_PATH"

LIBDNF5_PRESENT=0 run_system_update || fail "an install without libdnf5 bindings upgrades with dnf"
[[ $(<"$test_tmp/calls") == "dnf upgrade -y SUDO_USER=" ]] || fail "an install without libdnf5 bindings upgrades with dnf" "$(<"$test_tmp/calls")"
pass "an install that predates the migration upgrades once with plain dnf"

NOBARA=1 run_system_update || fail "Nobara fixups run before omadora-sync"
[[ $(<"$test_tmp/calls") == $'nobara-sync install-fixups SUDO_USER='"$EUID"$'\nomadora-sync cli SUDO_USER=' ]] ||
  fail "Nobara fixups run before omadora-sync with a numeric SUDO_USER" "$(<"$test_tmp/calls")"
NOBARA=1 FAIL_STEP=nobara-sync run_system_update || fail "a failed Nobara fixup stops the update" "$(<"$test_tmp/update.out")"
grep -q 'Nobara fixups failed' "$test_tmp/update.out" || fail "a failed Nobara fixup is reported"
grep -q '^omadora-sync cli' "$test_tmp/calls" || fail "a failed Nobara fixup still updates the system"
NOBARA=1 OMARCHY_UPDATE_RETRY=1 run_system_update || fail "the conflict retry reruns the update"
[[ $(<"$test_tmp/calls") == "omadora-sync cli SUDO_USER=" ]] || fail "the conflict retry repeats Nobara fixups" "$(<"$test_tmp/calls")"
pass "Nobara fixups run first without prompting, never block the update, and are not repeated on retry"
