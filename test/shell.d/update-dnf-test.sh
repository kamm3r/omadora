#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

stub_bin="$test_tmp/bin"
mkdir -p "$stub_bin"

cat >"$stub_bin/sudo" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >"$SUDO_CALL_LOG"
STUB
chmod +x "$stub_bin/sudo"

run_helper() {
  PATH="$stub_bin:$PATH" SUDO_CALL_LOG="$test_tmp/call" "$ROOT/bin/omarchy-update-dnf" "$@"
}

# The scope wrapper only applies on a systemd-booted host, so expect what the
# helper's own booted check would decide for this machine.
if [[ -d /run/systemd/system && ! -L /run/systemd/system ]]; then
  expected_scope="systemd-run --scope --quiet --collect "
else
  expected_scope=""
fi

run_helper dnf upgrade -y
[[ $(cat "$test_tmp/call") == "env OMARCHY_UPDATE_DNF=1 ${expected_scope}dnf upgrade -y" ]] ||
  fail "helper composes the guarded dnf invocation" "$(cat "$test_tmp/call")"
pass "helper composes the guarded dnf invocation"

LC_ALL=C run_helper dnf upgrade -y
[[ $(cat "$test_tmp/call") == "env OMARCHY_UPDATE_DNF=1 LC_ALL=C ${expected_scope}dnf upgrade -y" ]] ||
  fail "helper forwards LC_ALL to the transaction" "$(cat "$test_tmp/call")"
pass "helper forwards LC_ALL to the transaction"

run_helper nobara-sync cli
[[ $(cat "$test_tmp/call") == "env OMARCHY_UPDATE_DNF=1 ${expected_scope}nobara-sync cli" ]] ||
  fail "helper shields the nobara-sync transaction too" "$(cat "$test_tmp/call")"
pass "helper shields the nobara-sync transaction too"
