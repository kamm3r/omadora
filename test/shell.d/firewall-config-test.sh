#!/bin/bash

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/base-test.sh"

stub_dir=$(mktemp -d)
trap 'rm -rf "$stub_dir"' EXIT

cat >"$stub_dir/firewall-cmd" <<'STUB'
#!/bin/bash
printf 'firewall-cmd %s\n' "$*" >>"$TEST_LOG"
STUB

cat >"$stub_dir/systemctl" <<'STUB'
#!/bin/bash
printf 'systemctl %s\n' "$*" >>"$TEST_LOG"
STUB

chmod +x "$stub_dir"/*

export TEST_LOG="$stub_dir/firewall.log"
PATH="$stub_dir:$PATH" bash -eE -c 'source "$1"' bash "$ROOT/install/config/firewall.sh"

grep -q '^firewall-cmd --permanent --add-port=53317/tcp --add-port=53317/udp$' "$TEST_LOG" || fail "LocalSend ports are opened" "$(cat "$TEST_LOG")"
grep -q '^systemctl enable firewalld.service$' "$TEST_LOG" || fail "firewalld is enabled for next boot"
! grep -q '^firewall-cmd --reload' "$TEST_LOG" || fail "the install does not mutate the live firewall" "$(cat "$TEST_LOG")"

pass "firewall config opens LocalSend ports without touching the live firewall"
