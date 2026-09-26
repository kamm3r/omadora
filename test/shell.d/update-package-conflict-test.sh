#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

require_command script

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

stub_bin="$test_tmp/bin"
mkdir -p "$stub_bin"

cat >"$stub_bin/sudo" <<'STUB'
#!/bin/bash
exec "$@"
STUB

# omarchy-update-dnf wraps the transaction in a real PID 1 scope; the tests
# must stay inside the fixture, so drop the wrapper's options and run the command.
cat >"$stub_bin/systemd-run" <<'STUB'
#!/bin/bash
while [[ $1 == -* ]]; do shift; done
exec "$@"
STUB

# Pin the omadora-sync branch on any host: the libdnf5 bindings are reported
# installed whether or not this host has them.
cat >"$stub_bin/omarchy-pkg-present" <<'STUB'
#!/bin/bash
[[ $1 == python3-libdnf5 ]]
STUB

# Fails the first upgrade with the report under test, then succeeds. Every call
# records its arguments and which of its streams reached a terminal: dnf puts
# its questions on stderr once it is not running -y, so a retry meant for a
# person has to keep that stream.
cat >"$stub_bin/dnf" <<'STUB'
#!/bin/bash
attempt=$(($(cat "$DNF_ATTEMPTS") + 1))
echo "$attempt" >"$DNF_ATTEMPTS"
{
  printf 'args %s\n' "$*"
  for fd in 0 1 2; do
    if [[ -t $fd ]]; then printf 'tty%s yes\n' "$fd"; else printf 'tty%s no\n' "$fd"; fi
  done
} >>"$DNF_CALLS"

if ((attempt == 1)); then
  cat "$CONFLICT_REPORT" >&2
  exit 1
fi
echo "upgrade complete"
STUB

# omadora-sync runs first and never asks anything; the handler's interactive
# retry is raw dnf. Both count against the same attempts and call log.
# The update runs $OMARCHY_PATH/bin/omadora-sync, so it gets its own fake root.
fake_root="$test_tmp/omarchy"
mkdir -p "$fake_root/bin"
cp "$stub_bin/dnf" "$fake_root/bin/omadora-sync"

chmod +x "$stub_bin/sudo" "$stub_bin/systemd-run" "$stub_bin/omarchy-pkg-present" "$stub_bin/dnf" "$fake_root/bin/omadora-sync"

# Everything a blocked qemu-common upgrade leaves on stderr under dnf5, and no
# more: under -y dnf declines to erase anything and only suggests
# --allowerasing, so nothing downstream of the report can be built on a
# question it never asked.
write_conflict_report() {
  echo 0 >"$test_tmp/attempts"
  : >"$test_tmp/calls"
  {
    printf 'Failed to resolve the transaction:\n'
    printf 'Problem: cannot install both qemu-common-9.2.0-1.fc44.x86_64 and qemu-common-9.1.0-2.fc44.x86_64\n'
    printf '  - package qemu-block-gluster-9.1.0-2.fc44.x86_64 requires qemu-common = 9.1.0-2.fc44, but none of the providers can be installed\n'
    printf 'You can try to add to command line:\n'
    printf '  --allowerasing to allow erasing of installed packages to resolve problems\n'
  } >"$test_tmp/report"
}

update_env() {
  printf '%s\n' \
    "OMARCHY_REPLACED_DIR=$test_tmp/replaced" \
    "DNF_ATTEMPTS=$test_tmp/attempts" \
    "DNF_CALLS=$test_tmp/calls" \
    "CONFLICT_REPORT=$test_tmp/report" \
    "OWNED_PATHS=" \
    "OMARCHY_PATH=$fake_root" \
    "OMARCHY_UPDATE_UNATTENDED=${OMARCHY_UPDATE_UNATTENDED:-}" \
    "OMARCHY_UPDATE_INTERACTIVE=${OMARCHY_UPDATE_INTERACTIVE:-}" \
    "PATH=$stub_bin:$ROOT/bin:$PATH"
}

# No terminal on any stream, the way a cron or ssh caller arrives.
run_headless() {
  mapfile -t environment < <(update_env)
  env "${environment[@]}" bash "$ROOT/bin/omarchy-update-system-pkgs" \
    </dev/null >"$test_tmp/out" 2>"$test_tmp/err"
}

# script gives the update the pty that omarchy-update always runs it on, so the
# terminal checks see what a person at the keyboard would give them. Its
# transcript is stdout and stderr together, which is also what that person sees.
# $1 optionally takes one stream back off the pty.
run_on_terminal() {
  mapfile -t environment < <(update_env)
  env "${environment[@]}" \
    script -qec "bash '$ROOT/bin/omarchy-update-system-pkgs' ${1:-}" "$test_tmp/out" >/dev/null 2>&1
}

call_line() {
  awk -v call="$1" -v key="$2" \
    '$1 == "args" { n++ } n == call && $1 == key { sub(/^[^ ]+ /, ""); print }' "$test_tmp/calls"
}

write_conflict_report
run_on_terminal || fail "a package conflict is not resolved on a terminal"
(($(cat "$test_tmp/attempts") == 2)) ||
  fail "a package conflict does not get an interactive retry"
[[ $(call_line 1 args) == "cli" && " $(call_line 2 args) " == *" upgrade "* ]] ||
  fail "the interactive retry does not upgrade"
[[ " $(call_line 2 args) " != *" -y "* && " $(call_line 2 args) " != *" --assumeyes "* ]] ||
  fail "the interactive retry still answers dnf's questions itself"
[[ " $(call_line 2 args) " == *" --allowerasing "* ]] ||
  fail "the interactive retry cannot offer the erasure that resolves the conflict"
pass "a package conflict is put back to the person running the update"

[[ $(call_line 2 tty0) == "yes" && $(call_line 2 tty2) == "yes" ]] ||
  fail "the interactive retry cannot be answered: dnf has no terminal left"
pass "the interactive retry keeps the streams dnf asks and listens on"

# Which streams have to be a terminal follows from where dnf asks: stderr
# carries the question once -y is gone, stdin carries the answer, and
# stdout carries progress bars nobody has to see to answer.
write_conflict_report
run_on_terminal '>/dev/null' ||
  fail "a redirected progress stream is mistaken for an unattended update"
(($(cat "$test_tmp/attempts") == 2)) ||
  fail "a conflict goes unasked when only stdout is redirected"
pass "an answerable session is not turned away over its progress output"

write_conflict_report
if run_on_terminal '2>/dev/null'; then
  fail "a conflict is asked about on a stream nobody is reading"
fi
(($(cat "$test_tmp/attempts") == 1)) ||
  fail "dnf is left prompting where the question cannot be seen"
pass "a session that cannot show the question is not asked one"

[[ $(call_line 1 tty2) == "no" ]] ||
  fail "the first upgrade no longer captures the error report"
pass "the first upgrade still captures its errors for the handler"

write_conflict_report
if run_headless; then
  fail "a package conflict passes for a completed update without a terminal"
fi
(($(cat "$test_tmp/attempts") == 1)) ||
  fail "a package conflict is retried with no terminal to answer on"
grep -q 'omarchy update' "$test_tmp/err" ||
  fail "a package conflict with no terminal does not say how to answer it"
pass "a package conflict with no terminal reports instead of hanging"

write_conflict_report
if OMARCHY_UPDATE_UNATTENDED=1 run_on_terminal; then
  fail "an unattended update stops on a prompt nobody answers"
fi
(($(cat "$test_tmp/attempts") == 1)) ||
  fail "an unattended update prompts anyway"
pass "-y is kept: an unattended update never waits on an answer"

# The interactive upgrade skips the error capture the handler depends on, so
# reaching it any other way would lose the report that drives every recovery.
write_conflict_report
if OMARCHY_UPDATE_INTERACTIVE=1 run_headless; then
  fail "a caller reaches the interactive upgrade on its own"
fi
[[ $(call_line 1 args) == "cli" ]] ||
  fail "a caller can ask for an interactive upgrade directly"
pass "only the conflict handler can hand the upgrade to a person"
